import Foundation
import OSLog

nonisolated enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

nonisolated enum APIError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
    case transport
    case server(status: Int, code: String?)
    case serverWithDetails(status: Int, code: String?, details: APIErrorDetails)
    case decoding
}

nonisolated enum AuthenticationFailureHandling: Sendable {
    case awaitCompletion
    case deferred
}

/// Identifies the authenticated session that initiated a request.  A failure
/// from a request that outlives an account switch must not be applied to the
/// replacement session.
nonisolated struct AuthenticationSessionContext: Equatable, Sendable {
    let memberID: MemberID
    let generation: UInt64
}

nonisolated struct AuthenticationCookieSnapshot: Equatable, Sendable {
    let name: String
    let value: String
    let domain: String
    let path: String
    let isSecure: Bool
}

nonisolated struct AuthenticationRequestSnapshot: Sendable {
    let session: AuthenticationSessionContext?
    let epoch: UInt64
    let cookies: [AuthenticationCookieSnapshot]
}

nonisolated struct APIErrorDetails: Decodable, Equatable, Sendable {
    let remainingAttempts: Int?
}

nonisolated private struct ErrorResponse: Decodable {
    let code: String
    let details: APIErrorDetails?
}

private extension APIError {
    var isUnauthorized: Bool {
        switch self {
        case .server(status: 401, _), .serverWithDetails(status: 401, _, _):
            true
        default:
            false
        }
    }
}

actor RefreshGate {
    private var task: Task<Void, Error>?
    private(set) var generation = 0

    func run(
        ifGenerationIs observedGeneration: Int,
        _ operation: @escaping @Sendable () async throws -> Void
    ) async throws {
        guard generation == observedGeneration else { return }

        if let task {
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        self.task = task

        do {
            try await task.value
            generation &+= 1
            self.task = nil
        } catch {
            self.task = nil
            throw error
        }
    }

    func reset() {
        task?.cancel()
        task = nil
        generation &+= 1
    }
}

private actor AuthenticationMode {
    private let cookieStorage: HTTPCookieStorage?
    private var isImpersonating = false
    private var authenticationFailureHandler: (@Sendable () async -> Void)?
    private var contextualAuthenticationFailureHandler:
        (@Sendable (AuthenticationSessionContext?) async -> Void)?
    private var authenticationSessionContext: AuthenticationSessionContext?
    private var authenticationEpoch: UInt64 = 0

    init(cookieStorage: HTTPCookieStorage?) {
        self.cookieStorage = cookieStorage
    }

    func setImpersonating(_ value: Bool) {
        isImpersonating = value
    }

    var allowsRefresh: Bool {
        !isImpersonating
    }

    func setAuthenticationFailureHandler(
        _ handler: (@Sendable () async -> Void)?
    ) {
        authenticationFailureHandler = handler
        contextualAuthenticationFailureHandler = nil
    }

    func setContextualAuthenticationFailureHandler(
        _ handler: (@Sendable (AuthenticationSessionContext?) async -> Void)?
    ) {
        contextualAuthenticationFailureHandler = handler
        if handler != nil {
            authenticationFailureHandler = nil
        }
    }

    func setAuthenticationSessionContext(_ context: AuthenticationSessionContext?) {
        authenticationSessionContext = context
        authenticationEpoch &+= 1
    }

    func invalidateAuthenticationSession() {
        authenticationSessionContext = nil
        authenticationEpoch &+= 1
    }

    func invalidateAuthenticationSessionAndDeleteCookies() {
        invalidateAuthenticationSession()
        for cookie in cookieStorage?.cookies ?? []
        where cookie.name == "access_token" || cookie.name == "refresh_token" {
            cookieStorage?.deleteCookie(cookie)
        }
    }

    var requestSnapshot: AuthenticationRequestSnapshot {
        makeRequestSnapshot()
    }

    func requestSnapshot(
        ifEpochIs expectedEpoch: UInt64
    ) -> AuthenticationRequestSnapshot? {
        guard authenticationEpoch == expectedEpoch else { return nil }
        return makeRequestSnapshot()
    }

    func isCurrentEpoch(_ expectedEpoch: UInt64) -> Bool {
        authenticationEpoch == expectedEpoch
    }

    private func makeRequestSnapshot() -> AuthenticationRequestSnapshot {
        AuthenticationRequestSnapshot(
            session: authenticationSessionContext,
            epoch: authenticationEpoch,
            cookies: (cookieStorage?.cookies ?? []).map {
                AuthenticationCookieSnapshot(
                    name: $0.name,
                    value: $0.value,
                    domain: $0.domain,
                    path: $0.path,
                    isSecure: $0.isSecure
                )
            }
        )
    }

    func storeCookies(
        from response: HTTPURLResponse,
        ifEpochIs expectedEpoch: UInt64
    ) {
        guard let cookieStorage,
              let cookies = cookies(from: response)
        else {
            return
        }

        guard authenticationEpoch == expectedEpoch else {
            // URLSession may have automatic cookie handling enabled on a
            // caller-provided session. Remove only a stale value that is still
            // present; never delete a newer replacement cookie installed by a
            // later authentication transition.
            for cookie in cookies {
                guard let currentCookie = cookieStorage.cookies?.first(where: {
                    $0.name == cookie.name
                        && $0.domain == cookie.domain
                        && $0.path == cookie.path
                }), currentCookie.value == cookie.value
                else { continue }
                cookieStorage.deleteCookie(currentCookie)
            }
            return
        }

        guard let url = response.url else { return }
        cookieStorage.setCookies(cookies, for: url, mainDocumentURL: nil)
    }

    private func cookies(from response: HTTPURLResponse) -> [HTTPCookie]? {
        guard let url = response.url,
              let headerFields = response.allHeaderFields as? [String: String]
        else {
            return nil
        }
        return HTTPCookie.cookies(
            withResponseHeaderFields: headerFields,
            for: url
        )
    }

    func handleAuthenticationFailure(
        for context: AuthenticationSessionContext?
    ) async {
        if let contextualAuthenticationFailureHandler {
            await contextualAuthenticationFailureHandler(context)
        } else {
            await authenticationFailureHandler?()
        }
    }
}

nonisolated final class APIClient: Sendable {
    static let shared = APIClient()
    private static let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "io.github.shanepark.dutypark",
        category: "APIClient"
    )

    let baseURL: URL
    private let session: URLSession
    private let cookieStorage: HTTPCookieStorage?
    private let refreshGate = RefreshGate()
    private let authenticationMode: AuthenticationMode

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        let resolvedSession: URLSession
        let resolvedCookieStorage: HTTPCookieStorage?
        if let session {
            resolvedSession = session
            resolvedCookieStorage = session.configuration.httpCookieStorage
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = .shared
            // Cookie persistence is guarded by AuthenticationMode's request
            // epoch so a late response from a previous account cannot replace
            // the new account's credentials.
            configuration.httpShouldSetCookies = false
            configuration.timeoutIntervalForRequest = 30
            resolvedSession = URLSession(configuration: configuration)
            resolvedCookieStorage = .shared
        }
        self.session = resolvedSession
        self.cookieStorage = resolvedCookieStorage
        self.authenticationMode = AuthenticationMode(cookieStorage: resolvedCookieStorage)
    }

    func request<Response: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        authenticationFailureHandling: AuthenticationFailureHandling = .awaitCompletion
    ) async throws -> Response {
        let data = try await data(
            path,
            method: method,
            queryItems: queryItems,
            headers: headers,
            authenticationFailureHandling: authenticationFailureHandling
        )
        do {
            return try decode(Response.self, from: data)
        } catch {
            Self.logDecodeFailure(method: method, path: path, response: Response.self)
            throw error
        }
    }

    func request<Response: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Body,
        headers: [String: String] = [:],
        retryingAfterUnauthorized: Bool = true,
        authenticationFailureHandling: AuthenticationFailureHandling = .awaitCompletion
    ) async throws -> Response {
        let bodyData: Data
        do {
            bodyData = try JSONEncoder().encode(body)
        } catch {
            throw APIError.decoding
        }
        let data = try await data(
            path,
            method: method,
            queryItems: queryItems,
            body: bodyData,
            headers: headers,
            retryingAfterUnauthorized: retryingAfterUnauthorized,
            authenticationFailureHandling: authenticationFailureHandling
        )
        do {
            return try decode(Response.self, from: data)
        } catch {
            Self.logDecodeFailure(method: method, path: path, response: Response.self)
            throw error
        }
    }

    func optional<Response: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod = .get,
        retryingAfterUnauthorized: Bool = true
    ) async throws -> Response? {
        let data = try await data(
            path,
            method: method,
            retryingAfterUnauthorized: retryingAfterUnauthorized
        )
        guard !data.isEmpty else {
            return nil
        }
        do {
            return try decode(Response.self, from: data)
        } catch {
            Self.logDecodeFailure(method: method, path: path, response: Response.self)
            throw error
        }
    }

    @discardableResult
    func data(
        _ path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        retryingAfterUnauthorized: Bool = true,
        authenticationFailureHandling: AuthenticationFailureHandling = .awaitCompletion
    ) async throws -> Data {
        let authenticationSnapshot = await authenticationMode.requestSnapshot
        let observedRefreshGeneration = await refreshGate.generation
        let (data, response) = try await perform(
            path,
            method: method,
            queryItems: queryItems,
            body: body,
            headers: headers,
            authenticationEpoch: authenticationSnapshot.epoch,
            authenticationSession: authenticationSnapshot.session,
            authenticationCookies: authenticationSnapshot.cookies
        )

        if response.statusCode == 401, retryingAfterUnauthorized {
            if await authenticationMode.allowsRefresh {
                do {
                    try await refreshGate.run(ifGenerationIs: observedRefreshGeneration) { [self] in
                        let (refreshData, refreshResponse) = try await perform(
                            "auth/refresh",
                            method: .post,
                            authenticationEpoch: authenticationSnapshot.epoch,
                            authenticationSession: authenticationSnapshot.session,
                            authenticationCookies: authenticationSnapshot.cookies
                        )
                        try validate(refreshResponse, data: refreshData)
                    }
                } catch let error as APIError {
                    if error.isUnauthorized {
                        await handleAuthenticationFailure(
                            authenticationFailureHandling,
                            context: authenticationSnapshot.session
                        )
                    }
                    throw error
                }
                guard let retrySnapshot = await authenticationMode.requestSnapshot(
                    ifEpochIs: authenticationSnapshot.epoch
                ) else {
                    // The account changed while refresh was in flight. Do
                    // not retry with the replacement account's cookies.
                    throw CancellationError()
                }
                let (retryData, retryResponse) = try await perform(
                    path,
                    method: method,
                    queryItems: queryItems,
                    body: body,
                    headers: headers,
                    authenticationEpoch: retrySnapshot.epoch,
                    authenticationSession: retrySnapshot.session,
                    authenticationCookies: retrySnapshot.cookies
                )
                if retryResponse.statusCode == 401 {
                    await handleAuthenticationFailure(
                        authenticationFailureHandling,
                        context: authenticationSnapshot.session
                    )
                }
                try validate(retryResponse, data: retryData)
                return retryData
            }

            await handleAuthenticationFailure(
                authenticationFailureHandling,
                context: authenticationSnapshot.session
            )
        }

        try validate(response, data: data)
        return data
    }

    func setImpersonating(_ value: Bool) async {
        await authenticationMode.setImpersonating(value)
    }

    func setAuthenticationFailureHandler(
        _ handler: (@Sendable () async -> Void)?
    ) async {
        await authenticationMode.setAuthenticationFailureHandler(handler)
    }

    func setContextualAuthenticationFailureHandler(
        _ handler: (@Sendable (AuthenticationSessionContext?) async -> Void)?
    ) async {
        await authenticationMode.setContextualAuthenticationFailureHandler(handler)
    }

    func setAuthenticationSessionContext(
        _ context: AuthenticationSessionContext?
    ) async {
        await authenticationMode.setAuthenticationSessionContext(context)
    }

    func invalidateAuthenticationSession() async {
        await authenticationMode.invalidateAuthenticationSession()
        await refreshGate.reset()
    }

    func clearLocalAuthentication() async {
        // Epoch invalidation and credential deletion must be one actor
        // operation. Otherwise an old response can re-install a cookie in
        // the await gap between those two actions.
        await authenticationMode.invalidateAuthenticationSessionAndDeleteCookies()
        await refreshGate.reset()
        URLCache.shared.removeAllCachedResponses()
        await authenticationMode.setImpersonating(false)
        await authenticationMode.setAuthenticationFailureHandler(nil)
    }

    private func handleAuthenticationFailure(
        _ handling: AuthenticationFailureHandling,
        context: AuthenticationSessionContext?
    ) async {
        switch handling {
        case .awaitCompletion:
            await authenticationMode.handleAuthenticationFailure(for: context)
        case .deferred:
            Task { [authenticationMode] in
                await authenticationMode.handleAuthenticationFailure(for: context)
            }
        }
    }

    private func perform(
        _ path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        authenticationEpoch: UInt64,
        authenticationSession: AuthenticationSessionContext?,
        authenticationCookies: [AuthenticationCookieSnapshot]
    ) async throws -> (Data, HTTPURLResponse) {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            fatalError("Authenticated UI testing attempted a live API request: \(method.rawValue) \(path)")
        }
#endif
        let normalizedPath = path.drop(while: { $0 == "/" })
        guard !normalizedPath.split(separator: "/", omittingEmptySubsequences: false)
            .contains("..")
        else {
            throw APIError.invalidURL
        }
        guard var components = URLComponents(
            url: baseURL.appending(path: String(normalizedPath)),
            resolvingAgainstBaseURL: false
        ) else {
            throw APIError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        var request = URLRequest(url: url)
        // Cookie persistence is handled by AuthenticationMode so that a
        // response from an earlier auth epoch cannot overwrite a replacement
        // account.  Disable URLSession's automatic request/response cookie
        // handling for every session, including caller-provided sessions.
        request.httpShouldHandleCookies = false
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
        }
        if request.value(forHTTPHeaderField: "Cookie") == nil,
           let cookieHeader = Self.cookieHeader(
               for: url,
               cookies: authenticationCookies
           ) {
            request.setValue(cookieHeader, forHTTPHeaderField: "Cookie")
        }

        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw CancellationError()
        } catch {
            throw APIError.transport
        }
        guard let httpResponse = response as? HTTPURLResponse else {
            throw APIError.invalidResponse
        }
        await authenticationMode.storeCookies(
            from: httpResponse,
            ifEpochIs: authenticationEpoch
        )
        let carriesAuthenticationCookie = authenticationCookies.contains {
            $0.name == "access_token" || $0.name == "refresh_token"
        }
        if (authenticationSession != nil || carriesAuthenticationCookie),
           !(await authenticationMode.isCurrentEpoch(authenticationEpoch)) {
            // An authenticated response must not cross an account boundary.
            // Public/guest requests without an authenticated session or auth
            // cookie may complete normally while a login transition is in
            // progress.
            throw CancellationError()
        }
        return (data, httpResponse)
    }

    private func validate(_ response: HTTPURLResponse, data: Data) throws {
        guard (200..<300).contains(response.statusCode) else {
            let responseBody = try? JSONDecoder().decode(ErrorResponse.self, from: data)
            if let details = responseBody?.details {
                throw APIError.serverWithDetails(
                    status: response.statusCode,
                    code: responseBody?.code,
                    details: details
                )
            }
            throw APIError.server(status: response.statusCode, code: responseBody?.code)
        }
    }

    private func decode<Response: Decodable>(
        _ type: Response.Type,
        from data: Data
    ) throws -> Response {
        guard !data.isEmpty else {
            throw APIError.decoding
        }
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding
        }
    }

    private static func cookieHeader(
        for url: URL,
        cookies: [AuthenticationCookieSnapshot]
    ) -> String? {
        guard let host = url.host?.lowercased() else { return nil }
        let requestPath = url.path.isEmpty ? "/" : url.path
        let isHTTPS = url.scheme?.lowercased() == "https"
        let matchingCookies = cookies
            .filter { cookie in
                guard !cookie.isSecure || isHTTPS else { return false }
                let domain = cookie.domain
                    .trimmingCharacters(in: CharacterSet(charactersIn: "."))
                    .lowercased()
                guard host == domain || host.hasSuffix("." + domain) else {
                    return false
                }
                let path = cookie.path.isEmpty ? "/" : cookie.path
                return requestPath == path
                    || requestPath.hasPrefix(
                        path.hasSuffix("/") ? path : path + "/"
                    )
            }
            .sorted { lhs, rhs in
                if lhs.path.count != rhs.path.count {
                    return lhs.path.count > rhs.path.count
                }
                return lhs.name < rhs.name
            }
        guard !matchingCookies.isEmpty else { return nil }
        return matchingCookies
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }

    private static func logDecodeFailure<Response>(
        method: HTTPMethod,
        path: String,
        response: Response.Type
    ) {
        #if DEBUG
        logger.error(
            "Decode failed: \(method.rawValue, privacy: .public) \(path, privacy: .public) as \(String(describing: response), privacy: .public)"
        )
        #endif
    }
}
