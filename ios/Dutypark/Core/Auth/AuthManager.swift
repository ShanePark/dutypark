import Foundation

@MainActor
final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    @Published private(set) var isAuthenticated = false
    @Published private(set) var currentUser: LoginMember?
    @Published private(set) var isLoading = false

    private(set) var accessToken: String?
    private var refreshTokenValue: String?

    private init() {
        loadTokensFromKeychain()
    }

    private func loadTokensFromKeychain() {
        accessToken = KeychainHelper.get(.accessToken)
        refreshTokenValue = KeychainHelper.get(.refreshToken)
        isAuthenticated = accessToken != nil
    }

    func checkAuthStatus() async {
        guard accessToken != nil else {
            isAuthenticated = false
            return
        }

        do {
            let member = try await APIClient.shared.request(
                .authStatus,
                responseType: LoginMember.self
            )
            currentUser = member
            isAuthenticated = true
        } catch {
            isAuthenticated = false
            currentUser = nil
        }
    }

    func login(email: String, password: String) async throws {
        isLoading = true
        defer { isLoading = false }

        let response = try await APIClient.shared.request(
            .login(email: email, password: password),
            responseType: TokenResponse.self
        )

        try saveTokens(access: response.accessToken, refresh: response.refreshToken)
        isAuthenticated = true
        await checkAuthStatus()
    }

    func refreshToken() async throws {
        guard let refresh = refreshTokenValue else {
            throw APIError.unauthorized
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase

        #if DEBUG
        let baseURL = URL(string: "http://localhost:8080/api")!
        #else
        let baseURL = URL(string: "https://duty.park/api")!
        #endif

        var request = URLRequest(url: baseURL.appendingPathComponent("auth/refresh/bearer"))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(RefreshTokenRequest(refreshToken: refresh))

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw APIError.unauthorized
        }

        let tokenResponse = try decoder.decode(TokenResponse.self, from: data)
        try saveTokens(access: tokenResponse.accessToken, refresh: tokenResponse.refreshToken)
    }

    func logout() {
        KeychainHelper.deleteAll()
        accessToken = nil
        refreshTokenValue = nil
        isAuthenticated = false
        currentUser = nil
    }

    private func saveTokens(access: String, refresh: String) throws {
        try KeychainHelper.save(access, for: .accessToken)
        try KeychainHelper.save(refresh, for: .refreshToken)
        accessToken = access
        refreshTokenValue = refresh
    }
}
