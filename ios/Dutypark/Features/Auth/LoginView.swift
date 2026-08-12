import SwiftUI

struct LoginView: View {
    private static let rememberedEmailKey = "dp-remember-email"
    private let wrapsInNavigationStack: Bool

    @EnvironmentObject private var session: SessionStore
    @State private var email = UserDefaults.standard.string(forKey: rememberedEmailKey) ?? ""
    @State private var password = ""
    @State private var rememberEmail = UserDefaults.standard.string(forKey: rememberedEmailKey) != nil
    @State private var oauthClient = MobileOAuthClient()
    @State private var oauthErrorMessage: String?
    @State private var signupUUID: String?
    @State private var isOAuthWorking = false

    init(wrapsInNavigationStack: Bool = true) {
        self.wrapsInNavigationStack = wrapsInNavigationStack
    }

    var body: some View {
        Group {
            if wrapsInNavigationStack {
                NavigationStack { loginForm }
            } else {
                loginForm
            }
        }
        .sheet(
            isPresented: Binding(
                get: { signupUUID != nil },
                set: { if !$0 { signupUUID = nil } }
            )
        ) {
            if let signupUUID {
                SsoSignupView(uuid: signupUUID, oauthClient: oauthClient)
                    .environmentObject(session)
            }
        }
        .accessibilityIdentifier("screen.login")
    }

    private var loginForm: some View {
        Form {
            Section {
                TextField("auth.login.emailPlaceholder", text: $email)
                    .textContentType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .accessibilityLabel(Text("auth.login.emailLabel"))

                SecureField("auth.login.passwordPlaceholder", text: $password)
                    .textContentType(.password)
                    .accessibilityLabel(Text("auth.login.passwordLabel"))
                    .onSubmit(login)

                Toggle("auth.login.rememberMe", isOn: $rememberEmail)
            }

            if let errorKey = session.loginErrorKey {
                Section {
                    Text(LocalizedStringKey(errorKey))
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("login.error")
                    if let attemptsMessage = remainingAttemptsMessage {
                        Text(attemptsMessage)
                            .foregroundStyle(.orange)
                            .fontWeight(.medium)
                            .accessibilityIdentifier("login.remainingAttempts")
                    }
                }
            }

            Section {
                Button(action: login) {
                    HStack {
                        Spacer()
                        if session.isWorking {
                            ProgressView()
                        } else {
                            Text("auth.login.submit")
                        }
                        Spacer()
                    }
                }
                .disabled(session.isWorking || email.isEmpty || password.isEmpty)
                .accessibilityIdentifier("login.submit")
            }

            Section {
                Button { startOAuth(.kakao) } label: {
                    socialButton(oauthString("auth.oauth.kakao"))
                }
                .disabled(session.isWorking || isOAuthWorking)
                .accessibilityIdentifier("login.oauth.kakao")

                Button { startOAuth(.naver) } label: {
                    socialButton(oauthString("auth.oauth.naver"))
                }
                .disabled(session.isWorking || isOAuthWorking)
                .accessibilityIdentifier("login.oauth.naver")
            } header: {
                Text(oauthString("auth.oauth.divider"))
            }

            if let oauthErrorMessage {
                Section {
                    Text(verbatim: oauthErrorMessage)
                        .foregroundStyle(.red)
                        .accessibilityIdentifier("login.oauth.error")
                }
            }
        }
        .navigationTitle("Dutypark")
    }

    private var remainingAttemptsMessage: String? {
        guard let attempts = session.loginRemainingAttempts, attempts <= 3 else { return nil }
        switch attempts {
        case ...0:
            return String(localized: "auth.login.error.locked")
        case 1:
            return String(localized: "auth.login.error.lastAttempt")
        default:
            return String(
                format: String(localized: "auth.login.error.remainingAttempts"),
                locale: .current,
                attempts
            )
        }
    }

    private func login() {
        guard !email.isEmpty, !password.isEmpty else { return }
        if rememberEmail {
            UserDefaults.standard.set(email, forKey: Self.rememberedEmailKey)
        } else {
            UserDefaults.standard.removeObject(forKey: Self.rememberedEmailKey)
        }
        Task {
            await session.login(
                email: email,
                password: password,
                rememberMe: rememberEmail
            )
        }
    }

    private func socialButton(_ title: String) -> some View {
        HStack {
            Spacer()
            if isOAuthWorking {
                ProgressView()
            } else {
                Text(title)
            }
            Spacer()
        }
    }

    private func startOAuth(_ provider: OAuthProvider) {
        guard !isOAuthWorking else { return }
        isOAuthWorking = true
        oauthErrorMessage = nil
        Task {
            defer { isOAuthWorking = false }
            do {
                switch try await oauthClient.login(provider: provider) {
                case .authenticated:
                    try await session.finishExternalLogin()
                case .signup(let uuid):
                    signupUUID = uuid
                }
            } catch MobileOAuthError.cancelled {
                return
            } catch {
                oauthErrorMessage = error.localizedDescription
            }
        }
    }
}
