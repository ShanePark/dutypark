import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                VStack(spacing: 8) {
                    Text("Dutypark")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("근무표 관리의 시작")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                VStack(spacing: 16) {
                    TextField("이메일", text: $email)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.emailAddress)
                        .autocapitalization(.none)
                        .keyboardType(.emailAddress)

                    SecureField("비밀번호", text: $password)
                        .textFieldStyle(.roundedBorder)
                        .textContentType(.password)

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
                .padding(.horizontal, 32)

                Spacer()

                VStack(spacing: 12) {
                    Button("카카오로 로그인") {
                        // TODO: Kakao OAuth
                    }
                    .buttonStyle(.bordered)

                    Button("회원가입") {
                        // TODO: Navigate to signup
                    }
                    .font(.footnote)
                }

                Spacer()
            }
            .alert("로그인 실패", isPresented: $showError) {
                Button("확인", role: .cancel) {}
            } message: {
                Text(errorMessage)
            }
        }
    }

    private func login() async {
        do {
            try await authManager.login(email: email, password: password)
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
