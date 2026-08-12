import Foundation

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

nonisolated struct APIErrorDetails: Decodable, Equatable, Sendable {
    let remainingAttempts: Int?
}

nonisolated private struct ErrorResponse: Decodable {
    let code: String
    let details: APIErrorDetails?
}

actor RefreshGate {
    private var task: Task<Void, Error>?

    func run(_ operation: @escaping @Sendable () async throws -> Void) async throws {
        if let task {
            return try await task.value
        }

        let task = Task {
            try await operation()
        }
        self.task = task

        do {
            try await task.value
            self.task = nil
        } catch {
            self.task = nil
            throw error
        }
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
        headers: [String: String] = [:]
    ) async throws -> Response {
        let data = try await data(
            path,
            method: method,
            queryItems: queryItems,
            headers: headers
        )
        return try decode(Response.self, from: data)
    }

    func request<Response: Decodable & Sendable, Body: Encodable & Sendable>(
        _ path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Body,
        headers: [String: String] = [:],
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
            retryingAfterUnauthorized: retryingAfterUnauthorized
        )
        return try decode(Response.self, from: data)
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
        return try decode(Response.self, from: data)
    }

    @discardableResult
    func data(
        _ path: String,
        method: HTTPMethod = .get,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:],
        retryingAfterUnauthorized: Bool = true
    ) async throws -> Data {
        let (data, response) = try await perform(
            path,
            method: method,
            queryItems: queryItems,
            body: body,
            headers: headers
        )

        if response.statusCode == 401,
           retryingAfterUnauthorized,
           await authenticationMode.allowsRefresh {
            do {
                try await refreshGate.run { [self] in
                    let (refreshData, refreshResponse) = try await perform(
                        "auth/refresh",
                        method: .post
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
                headers: headers
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

    private func perform(
        _ path: String,
        method: HTTPMethod,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        headers: [String: String] = [:]
    ) async throws -> (Data, HTTPURLResponse) {
        guard var components = URLComponents(
            url: baseURL.appending(path: path),
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
}
