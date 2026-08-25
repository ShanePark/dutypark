import AuthenticationServices
import SwiftUI

struct LoginView: View {
    private static let rememberedEmailKey = "dp-remember-email"
    private let wrapsInNavigationStack: Bool

    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var email = UserDefaults.standard.string(forKey: rememberedEmailKey) ?? ""
    @State private var password = ""
    @State private var rememberEmail = UserDefaults.standard.string(forKey: rememberedEmailKey) != nil
    @State private var oauthClient = MobileOAuthClient()
    @State private var appleSignInClient = AppleSignInClient()
    @State private var oauthErrorMessage: String?
    @State private var signupUUID: String?
    @State private var activeOAuthProvider: OAuthProvider?
    @State private var appleSignInAttempt: AppleSignInAttempt?
    @FocusState private var focusedField: LoginField?

    private enum LoginField {
        case email
        case password
    }

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
        .dpKeyboardDismissToolbar()
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
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: 0) {
                    VStack(spacing: 8) {
                        Text("Dutypark")
                            .font(DPFont.bold(size: 30, relativeTo: .largeTitle))
                            .foregroundStyle(DPColor.textPrimary)
                        Text("auth.login.subtitle")
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .padding(.bottom, 32)

                    VStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("auth.login.emailLabel")
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textSecondary)

                            TextField("auth.login.emailPlaceholder", text: $email)
                                .font(DPTypography.body)
                                .textContentType(.emailAddress)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit { focusedField = .password }
                                .dpInputChrome(isFocused: focusedField == .email)
                                .accessibilityLabel(Text("auth.login.emailLabel"))

                            Button {
                                rememberEmail.toggle()
                                DPHapticCenter.shared.emit(.selection)
                            } label: {
                                HStack(spacing: 8) {
                                    Image(systemName: rememberEmail ? "checkmark.square.fill" : "square")
                                        .font(.system(size: 18))
                                        .foregroundStyle(
                                            rememberEmail ? DPColor.accent : DPColor.textSecondary
                                        )
                                    Text("auth.login.rememberMe")
                                        .font(DPTypography.label)
                                        .foregroundStyle(DPColor.textSecondary)
                                }
                                .frame(minHeight: DPSize.minimumTouchTarget)
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            Text("auth.login.passwordLabel")
                                .font(DPTypography.label)
                                .foregroundStyle(DPColor.textSecondary)

                            SecureField("auth.login.passwordPlaceholder", text: $password)
                                .font(DPTypography.body)
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($focusedField, equals: .password)
                                .onSubmit(login)
                                .dpInputChrome(isFocused: focusedField == .password)
                                .accessibilityLabel(Text("auth.login.passwordLabel"))
                        }

                        if let loginErrorMessage {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: loginErrorMessage)
                                    .accessibilityIdentifier("login.error")
                                if let attemptsMessage = remainingAttemptsMessage {
                                    Text(attemptsMessage)
                                        .font(DPFont.bold(size: 13, relativeTo: .caption))
                                        .accessibilityIdentifier("login.remainingAttempts")
                                }
                            }
                            .font(DPTypography.supporting)
                            .foregroundStyle(
                                session.loginRemainingAttempts.map { $0 <= 1 } == true
                                    ? DPColor.warning
                                    : DPColor.danger
                            )
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(12)
                            .background(
                                session.loginRemainingAttempts.map { $0 <= 1 } == true
                                    ? DPColor.warningSoft
                                    : DPColor.dangerSoft
                            )
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                            .overlay {
                                RoundedRectangle(cornerRadius: DPRadius.large)
                                    .stroke(
                                        session.loginRemainingAttempts.map { $0 <= 1 } == true
                                            ? DPColor.warningBorder
                                            : DPColor.dangerBorder
                                    )
                            }
                        }

                        Button(action: login) {
                            Group {
                                if session.isWorking {
                                    ProgressView()
                                        .tint(DPColor.textOnDark)
                                } else {
                                    Text("auth.login.submit")
                                }
                            }
                            .font(DPFont.bold(size: 16, relativeTo: .headline))
                            .foregroundStyle(DPColor.textOnDark)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(DPColor.surfaceStrong)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                            .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(!canLogin)
                        .opacity(canLogin ? 1 : 0.5)
                        .accessibilityIdentifier("login.submit")

                        HStack(spacing: 16) {
                            Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
                            Text("auth.login.or")
                                .font(DPTypography.supporting)
                                .foregroundStyle(DPColor.textMuted)
                            Rectangle().fill(DPColor.borderPrimary).frame(height: 1)
                        }
                        .padding(.vertical, 4)

                        VStack(spacing: 12) {
                            SignInWithAppleButton(
                                .signIn,
                                onRequest: prepareAppleSignIn,
                                onCompletion: completeAppleSignIn
                            )
                            .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                            .frame(maxWidth: .infinity, minHeight: 52, maxHeight: 52)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                            .overlay {
                                if oauthButtonPresentation(for: .apple).showsProgress {
                                    ProgressView()
                                        .tint(colorScheme == .dark ? .black : .white)
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                        .background(colorScheme == .dark ? Color.white : Color.black)
                                }
                            }
                            .disabled(oauthButtonPresentation(for: .apple).isDisabled)
                            .accessibilityIdentifier("login.oauth.apple")

                            Button { startOAuth(.kakao) } label: {
                                socialButton(
                                    oauthString("auth.oauth.kakao"),
                                    provider: .kakao,
                                    image: "KakaoLogo",
                                    background: SocialBrandColor.kakao,
                                    foreground: .black
                                )
                            }
                            .disabled(oauthButtonPresentation(for: .kakao).isDisabled)
                            .accessibilityIdentifier("login.oauth.kakao")

                            Button { startOAuth(.naver) } label: {
                                socialButton(
                                    oauthString("auth.oauth.naver"),
                                    provider: .naver,
                                    image: "NaverLogo",
                                    background: SocialBrandColor.naver,
                                    foreground: DPColor.textOnDark
                                )
                            }
                            .disabled(oauthButtonPresentation(for: .naver).isDisabled)
                            .accessibilityIdentifier("login.oauth.naver")
                        }

                        if let oauthErrorMessage {
                            Text(verbatim: oauthErrorMessage)
                                .font(DPTypography.supporting)
                                .foregroundStyle(DPColor.danger)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .accessibilityIdentifier("login.oauth.error")
                        }
                    }
                    .padding(32)
                    .background(DPColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.extraLarge))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.extraLarge)
                            .stroke(DPColor.borderPrimary)
                    }
                    .shadow(color: .black.opacity(0.06), radius: 3, y: 1)

                    Button {
                        DPHapticCenter.shared.emit(.routine)
                        dismiss()
                    } label: {
                        Text("auth.login.backHome")
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textPrimary)
                            .frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 16)

                    HStack(spacing: 8) {
                        NavigationLink(
                            GuestLocalization.text("guest.policy.terms"),
                            value: GuestRoute.terms
                        )
                        Text("|")
                        NavigationLink(
                            GuestLocalization.text("guest.policy.privacy"),
                            value: GuestRoute.privacy
                        )
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                }
                .frame(maxWidth: 448)
                .frame(minHeight: geometry.size.height)
                .padding(.horizontal, 16)
                .padding(.vertical, 16)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .background(DPColor.backgroundSecondary)
        .toolbar(.hidden, for: .navigationBar)
        .dpInteractivePopGestureEnabled()
    }

    private var loginErrorMessage: String? {
        guard let key = session.loginErrorKey else { return nil }
        return LoginErrorMessage.text(key: key, status: session.loginErrorStatus)
    }

    private var remainingAttemptsMessage: String? {
        LoginAttemptMessage.text(remainingAttempts: session.loginRemainingAttempts)
    }

    private var canLogin: Bool {
        !session.isWorking &&
            !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !password.isEmpty
    }

    private func login() {
        guard canLogin else { return }
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

    private func socialButton(
        _ title: String,
        provider: OAuthProvider,
        image: String,
        background: Color,
        foreground: Color
    ) -> some View {
        HStack(spacing: 12) {
            if oauthButtonPresentation(for: provider).showsProgress {
                ProgressView()
                    .tint(foreground)
            } else {
                Image(image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
                Text(title)
            }
        }
        .font(DPFont.bold(size: 16, relativeTo: .headline))
        .foregroundStyle(foreground)
        .frame(maxWidth: .infinity, minHeight: 52)
        .background(background)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .contentShape(Rectangle())
    }

    private func oauthButtonPresentation(for provider: OAuthProvider) -> LoginOAuthButtonPresentation {
        LoginOAuthButtonPresentation(
            provider: provider,
            activeProvider: activeOAuthProvider,
            isSessionWorking: session.isWorking
        )
    }

    private func startOAuth(_ provider: OAuthProvider) {
        guard provider != .apple else { return }
        guard activeOAuthProvider == nil else { return }
        activeOAuthProvider = provider
        oauthErrorMessage = nil
        Task {
            defer { activeOAuthProvider = nil }
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
                oauthErrorMessage = OAuthLoginErrorMessage.text(for: error)
                DPHapticCenter.shared.emit(.error)
            }
        }
    }

    private func prepareAppleSignIn(_ request: ASAuthorizationAppleIDRequest) {
        guard activeOAuthProvider == nil else { return }
        oauthErrorMessage = nil
        do {
            appleSignInAttempt = try appleSignInClient.configure(request)
            activeOAuthProvider = .apple
        } catch {
            appleSignInAttempt = nil
            oauthErrorMessage = OAuthLoginErrorMessage.text(for: error)
            DPHapticCenter.shared.emit(.error)
        }
    }

    private func completeAppleSignIn(_ result: Result<ASAuthorization, Error>) {
        guard let attempt = appleSignInAttempt else {
            activeOAuthProvider = nil
            oauthErrorMessage = OAuthLoginErrorMessage.text(
                for: AppleSignInError.invalidCredential
            )
            DPHapticCenter.shared.emit(.error)
            return
        }
        Task {
            defer {
                appleSignInAttempt = nil
                activeOAuthProvider = nil
            }
            do {
                switch try await appleSignInClient.completeLogin(result: result, attempt: attempt) {
                case .authenticated:
                    try await session.finishExternalLogin()
                case .signup(let uuid):
                    signupUUID = uuid
                }
            } catch AppleSignInError.cancelled {
                return
            } catch {
                oauthErrorMessage = OAuthLoginErrorMessage.text(for: error)
                DPHapticCenter.shared.emit(.error)
            }
        }
    }
}

nonisolated enum LoginErrorMessage {
    /// Server side failures carry their HTTP status so a user can report what happened.
    static func text(key: String, status: Int?, locale: Locale? = nil) -> String {
        if key == "auth.account.suspended" {
            return APIErrorLocalization.message(code: key, bundle: AppLocalization.bundle(for: locale))
        }
        guard let status else {
            return AppLocalization.string(key, table: "Localizable", locale: locale)
        }
        return AppLocalization.format(
            key,
            table: "Localizable",
            arguments: [status],
            locale: locale
        )
    }
}

nonisolated enum LoginAttemptMessage {
    static func text(remainingAttempts: Int?, locale: Locale? = nil) -> String? {
        guard let remainingAttempts, remainingAttempts <= 3 else { return nil }
        switch remainingAttempts {
        case ...0:
            return AppLocalization.string("auth.login.error.locked", table: "Localizable", locale: locale)
        case 1:
            return AppLocalization.string("auth.login.error.lastAttempt", table: "Localizable", locale: locale)
        default:
            return AppLocalization.format(
                "auth.login.error.remainingAttempts",
                table: "Localizable",
                arguments: [remainingAttempts],
                locale: locale
            )
        }
    }
}

nonisolated enum OAuthLoginErrorMessage {
    static func text(for error: any Error) -> String {
        switch error {
        case let error as MobileOAuthError:
            return error.localizedDescription
        case let error as AppleSignInError:
            return error.localizedDescription
        case let error as APIError:
            return error.localizedDescription
        default:
            return oauthString("auth.oauth.error")
        }
    }
}

nonisolated struct LoginOAuthButtonPresentation: Equatable {
    let showsProgress: Bool
    let isDisabled: Bool

    init(
        provider: OAuthProvider,
        activeProvider: OAuthProvider?,
        isSessionWorking: Bool
    ) {
        showsProgress = activeProvider == provider
        isDisabled = isSessionWorking || activeProvider != nil
    }
}

private enum SocialBrandColor {
    static let kakao = Color(red: 254 / 255, green: 229 / 255, blue: 0)
    static let naver = Color(red: 3 / 255, green: 199 / 255, blue: 90 / 255)
}
