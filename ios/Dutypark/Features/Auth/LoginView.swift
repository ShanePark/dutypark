import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""
    @AppStorage("rememberEmail") private var rememberEmail = false
    @AppStorage("savedEmail") private var savedEmail = ""
    @State private var showTerms = false
    @State private var showPrivacy = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "chevron.left")
                            .font(.caption)
                        Text("홈으로 돌아가기")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Dutypark")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("로그인하여 시작하세요")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                VStack(spacing: 16) {
                    TextField("이메일", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .textInputAutocapitalization(.never)
                        .keyboardType(.emailAddress)

                    SecureField("비밀번호", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

                    HStack(spacing: 8) {
                        Button {
                            rememberEmail.toggle()
                        } label: {
                            Image(systemName: rememberEmail ? "checkmark.square.fill" : "square")
                                .foregroundColor(rememberEmail ? DesignSystem.Colors.accent : .secondary)
                        }
                        Text("아이디 저장")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }

                    Button {
                        Task {
                            await login()
                        }
                    } label: {
                        if authManager.isLoading {
                            ProgressView()
                                .frame(maxWidth: .infinity)
                        } else {
                            Text("로그인")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                }

                HStack(spacing: 12) {
                    Divider()
                    Text("또는")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Divider()
                }

                Button {
                    // TODO: Kakao OAuth
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "message.fill")
                            .font(.subheadline)
                        Text("카카오로 로그인")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(DesignSystem.Colors.kakao)
                    .foregroundColor(DesignSystem.Colors.kakaoText)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }

                Button("회원가입") {
                    // TODO: Navigate to signup
                }
                .font(.footnote)
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    Button("이용약관") {
                        showTerms = true
                    }
                    Text("|")
                        .foregroundColor(.secondary)
                    Button("개인정보 처리방침") {
                        showPrivacy = true
                    }
                }
                .font(.footnote)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 32)
            .padding(.vertical, 24)
        }
        .scrollDismissesKeyboard(.interactively)
        .sheet(isPresented: $showTerms) {
            PolicyModal(type: .terms)
        }
        .sheet(isPresented: $showPrivacy) {
            PolicyModal(type: .privacy)
        }
        .onAppear {
            if rememberEmail {
                email = savedEmail
            }
        }
        .onChange(of: email) { _, newValue in
            if rememberEmail {
                savedEmail = newValue
            }
        }
        .onChange(of: rememberEmail) { _, newValue in
            if newValue {
                savedEmail = email
            } else {
                savedEmail = ""
            }
        }
        .alert("로그인 실패", isPresented: $showError) {
            Button("확인", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
    }

    private func login() async {
        do {
            try await authManager.login(email: email, password: password)
            if rememberEmail {
                savedEmail = email
            } else {
                savedEmail = ""
            }
        } catch {
            errorMessage = error.localizedDescription
            showError = true
        }
    }
}

#Preview {
    LoginView()
        .environmentObject(AuthManager.shared)
}
