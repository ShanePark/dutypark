import SwiftUI

struct AdminPasswordSheet: View {
    @ObservedObject var viewModel: AdminDashboardViewModel
    let member: AdminMemberDto
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var newPassword = ""
    @State private var confirmPassword = ""
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    Text("\(member.name)님의 비밀번호를 변경합니다")
                        .font(.subheadline)
                        .foregroundColor(textSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        Text("새 비밀번호")
                            .font(.caption)
                            .foregroundColor(textMuted)

                        SecureField("새 비밀번호 입력", text: $newPassword)
                            .textContentType(.newPassword)
                            .padding(DesignSystem.Spacing.lg)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                            .cornerRadius(DesignSystem.CornerRadius.md)

                        SecureField("새 비밀번호 확인", text: $confirmPassword)
                            .textContentType(.newPassword)
                            .padding(DesignSystem.Spacing.lg)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                    }

                    if !confirmPassword.isEmpty && confirmPassword != newPassword {
                        Text("비밀번호가 일치하지 않습니다")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.danger)
                    } else if !newPassword.isEmpty && newPassword.count < 8 {
                        Text("비밀번호는 8자 이상이어야 합니다")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.warning)
                    }

                    Spacer()
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("비밀번호 변경")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "변경 중..." : "변경") {
                        changePassword()
                    }
                    .disabled(!isValid || isSaving)
                }
            }
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var isValid: Bool {
        !newPassword.isEmpty && newPassword.count >= 8 && newPassword == confirmPassword
    }

    private var textSecondary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary
    }

    private var textMuted: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted
    }

    private func changePassword() {
        isSaving = true
        Task {
            let success = await viewModel.changePassword(memberId: member.id, newPassword: newPassword)
            if success {
                dismiss()
            } else {
                errorMessage = viewModel.error ?? "비밀번호 변경에 실패했습니다"
                showError = true
            }
            isSaving = false
        }
    }
}

#Preview {
    AdminPasswordSheet(
        viewModel: AdminDashboardViewModel(),
        member: AdminMemberDto(id: 1, name: "홍길동", email: nil, teamId: nil, teamName: nil, tokens: [], hasProfilePhoto: nil, profilePhotoVersion: nil)
    )
}
