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

/// Selects the server API namespace while preserving the same cookie and
/// authentication lifecycle. Admin requests use `/admin/api/**`; token refresh
/// always remains on `/api/auth/refresh`.
nonisolated enum APIRequestScope: Sendable {
    case api
    case admin
}

nonisolated struct APIErrorDetails: Decodable, Equatable, Sendable {
    let remainingAttempts: Int?
}

nonisolated private struct ErrorResponse: Decodable {
    let code: String
    let details: APIErrorDetails?
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
    private var isImpersonating = false
    private var authenticationFailureHandler: (@Sendable () async -> Void)?

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
    }

    func handleAuthenticationFailure() async {
        await authenticationFailureHandler?()
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
    private let authenticationMode = AuthenticationMode()

    init(
        baseURL: URL = AppConfiguration.apiBaseURL,
        session: URLSession? = nil
    ) {
        self.baseURL = baseURL
        if let session {
            self.session = session
            self.cookieStorage = session.configuration.httpCookieStorage
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.httpCookieStorage = .shared
            configuration.httpShouldSetCookies = true
            configuration.timeoutIntervalForRequest = 30
            self.session = URLSession(configuration: configuration)
            self.cookieStorage = .shared
        }
    }

    func request<Response: Decodable & Sendable>(
        _ path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        headers: [String: String] = [:],
        scope: APIRequestScope = .api
    ) async throws -> Response {
        let data = try await data(
            path,
            method: method,
            queryItems: queryItems,
            headers: headers,
            scope: scope
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
        scope: APIRequestScope = .api,
        retryingAfterUnauthorized: Bool = true
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
            scope: scope,
            retryingAfterUnauthorized: retryingAfterUnauthorized
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
        scope: APIRequestScope = .api,
        retryingAfterUnauthorized: Bool = true
    ) async throws -> Response? {
        let data = try await data(
            path,
            method: method,
            scope: scope,
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
        scope: APIRequestScope = .api,
        retryingAfterUnauthorized: Bool = true
    ) async throws -> Data {
        let observedRefreshGeneration = await refreshGate.generation
        let (data, response) = try await perform(
            path,
            method: method,
            queryItems: queryItems,
            body: body,
            headers: headers,
            scope: scope
        )

        if response.statusCode == 401,
           retryingAfterUnauthorized,
           await authenticationMode.allowsRefresh {
            do {
                try await refreshGate.run(ifGenerationIs: observedRefreshGeneration) { [self] in
                    let (refreshData, refreshResponse) = try await perform(
                        "auth/refresh",
                        method: .post,
                        scope: .api
                    )
                    try validate(refreshResponse, data: refreshData)
                }
            } catch let error as APIError {
                if case .server(status: 401, code: _) = error {
                    await authenticationMode.handleAuthenticationFailure()
                }
                throw error
            }
            let (retryData, retryResponse) = try await perform(
                path,
                method: method,
                queryItems: queryItems,
                body: body,
                headers: headers,
                scope: scope
            )
            try validate(retryResponse, data: retryData)
            return retryData
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

    func clearLocalAuthentication() async {
        for cookie in cookieStorage?.cookies ?? []
        where cookie.name == "access_token" || cookie.name == "refresh_token" {
            cookieStorage?.deleteCookie(cookie)
        }
        URLCache.shared.removeAllCachedResponses()
        await refreshGate.reset()
        await authenticationMode.setImpersonating(false)
        await authenticationMode.setAuthenticationFailureHandler(nil)
    }

    private func perform(
        _ path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        scope: APIRequestScope = .api
    ) async throws -> (Data, HTTPURLResponse) {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            fatalError("Authenticated UI testing attempted a live API request: \(method.rawValue) \(path)")
        }
#endif
        guard let scopedBaseURL = AppConfiguration.baseURL(
            for: scope,
            apiBaseURL: baseURL
        ) else {
            throw APIError.invalidURL
        }
        let normalizedPath = path.drop(while: { $0 == "/" })
        guard !normalizedPath.split(separator: "/", omittingEmptySubsequences: false)
            .contains("..")
        else {
            throw APIError.invalidURL
        }
        guard var components = URLComponents(
            url: scopedBaseURL.appending(path: String(normalizedPath)),
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
        request.httpMethod = method.rawValue
        request.httpBody = body
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if body != nil {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        for (name, value) in headers {
            request.setValue(value, forHTTPHeaderField: name)
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
        storeCookies(from: httpResponse)
        return (data, httpResponse)
    }

    private func storeCookies(from response: HTTPURLResponse) {
        guard let cookieStorage,
              let url = response.url,
              let headerFields = response.allHeaderFields as? [String: String]
        else {
            return
        }
        let cookies = HTTPCookie.cookies(
            withResponseHeaderFields: headerFields,
            for: url
        )
        cookieStorage.setCookies(cookies, for: url, mainDocumentURL: nil)
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
