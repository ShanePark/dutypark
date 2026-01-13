import SwiftUI

struct CreateTeamSheet: View {
    @ObservedObject var viewModel: AdminTeamListViewModel
    let onCreated: ((Int) -> Void)?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @State private var teamName = ""
    @State private var teamDescription = ""
    @State private var nameCheckResult: TeamNameCheckResult?
    @State private var isCheckingName = false
    @State private var isSaving = false
    @State private var showError = false
    @State private var errorMessage = ""

    var body: some View {
        NavigationStack {
            ZStack {
                (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                    .ignoresSafeArea()

                VStack(spacing: DesignSystem.Spacing.lg) {
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("팀 이름")
                                .font(.caption)
                                .foregroundColor(textMuted)
                            Spacer()
                            Text("\(teamName.count)/20")
                                .font(.caption2)
                                .foregroundColor(textMuted)
                        }

                        HStack(spacing: DesignSystem.Spacing.sm) {
                            TextField("팀 이름 입력", text: $teamName)
                                .textInputAutocapitalization(.never)
                                .disableAutocorrection(true)
                                .padding(DesignSystem.Spacing.lg)
                                .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                                .cornerRadius(DesignSystem.CornerRadius.md)
                                .onChange(of: teamName) { _, _ in
                                    nameCheckResult = nil
                                    if teamName.count > 20 {
                                        teamName = String(teamName.prefix(20))
                                    }
                                }

                            Button {
                                Task { await checkName() }
                            } label: {
                                if isCheckingName {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .frame(width: 20, height: 20)
                                } else {
                                    Text("확인")
                                        .font(.caption)
                                }
                            }
                            .foregroundColor(.white)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                            .background(DesignSystem.Colors.accent)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .disabled(teamName.isEmpty || isCheckingName)
                        }

                        if let nameCheckResult {
                            Text(nameCheckMessage(for: nameCheckResult))
                                .font(.caption)
                                .foregroundColor(nameCheckResult == .ok ? DesignSystem.Colors.success : DesignSystem.Colors.danger)
                        }
                    }

                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack {
                            Text("설명")
                                .font(.caption)
                                .foregroundColor(textMuted)
                            Spacer()
                            Text("\(teamDescription.count)/50")
                                .font(.caption2)
                                .foregroundColor(textMuted)
                        }

                        TextField("팀 설명 입력", text: $teamDescription)
                            .padding(DesignSystem.Spacing.lg)
                            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                            .cornerRadius(DesignSystem.CornerRadius.md)
                            .onChange(of: teamDescription) { _, _ in
                                if teamDescription.count > 50 {
                                    teamDescription = String(teamDescription.prefix(50))
                                }
                            }
                    }

                    Spacer()
                }
                .padding(DesignSystem.Spacing.lg)
            }
            .navigationTitle("새 팀 추가")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(isSaving ? "추가 중..." : "추가") {
                        Task { await createTeam() }
                    }
                    .disabled(!canSubmit || isSaving)
                }
            }
            .alert("오류", isPresented: $showError) {
                Button("확인", role: .cancel) { }
            } message: {
                Text(errorMessage)
            }
        }
    }

    private var canSubmit: Bool {
        nameCheckResult == .ok && !teamDescription.isEmpty
    }

    private var textMuted: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted
    }

    private func checkName() async {
        guard teamName.count >= 2 else {
            nameCheckResult = .tooShort
            return
        }
        guard teamName.count <= 20 else {
            nameCheckResult = .tooLong
            return
        }
        isCheckingName = true
        if let result = await viewModel.checkTeamName(teamName) {
            nameCheckResult = result
        } else {
            errorMessage = viewModel.error ?? "팀 이름 확인에 실패했습니다"
            showError = true
        }
        isCheckingName = false
    }

    private func createTeam() async {
        isSaving = true
        if let teamId = await viewModel.createTeam(name: teamName, description: teamDescription) {
            onCreated?(teamId)
            dismiss()
        } else {
            errorMessage = viewModel.error ?? "팀 생성에 실패했습니다"
            showError = true
        }
        isSaving = false
    }

    private func nameCheckMessage(for result: TeamNameCheckResult) -> String {
        switch result {
        case .ok:
            return "사용 가능한 팀 이름입니다"
        case .tooShort:
            return "팀 이름은 2자 이상이어야 합니다"
        case .tooLong:
            return "팀 이름은 20자 이하여야 합니다"
        case .duplicated:
            return "이미 존재하는 팀 이름입니다"
        }
    }
}

#Preview {
    CreateTeamSheet(viewModel: AdminTeamListViewModel(), onCreated: nil)
}
