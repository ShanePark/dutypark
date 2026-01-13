import SwiftUI

enum PolicyType: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms:
            return "이용약관"
        case .privacy:
            return "개인정보 처리방침"
        }
    }
}

struct PolicyDetailView: View {
    let type: PolicyType
    @Environment(\.colorScheme) var colorScheme
    @State private var policy: PolicyDto?
    @State private var isLoading = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.lg) {
                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                } else if let policy = policy {
                    Text("시행일: \(policy.effectiveDate)")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary)

                    markdownText(policy.content)
                        .font(.body)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary)
                } else {
                    Text(errorMessage ?? "정책 정보를 불러올 수 없습니다.")
                        .font(.subheadline)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }
            .padding(DesignSystem.Spacing.lg)
        }
        .navigationTitle(type.title)
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadPolicy()
        }
    }

    @ViewBuilder
    private func markdownText(_ content: String) -> some View {
        if let attributed = try? AttributedString(markdown: content) {
            Text(attributed)
        } else {
            Text(content)
        }
    }

    private func loadPolicy() async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await APIClient.shared.request(
                .policy(type: type.rawValue),
                responseType: PolicyDto.self
            )
            policy = response
        } catch {
            errorMessage = error.localizedDescription
            policy = nil
        }

        isLoading = false
    }
}

struct PolicyModal: View {
    let type: PolicyType
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            PolicyDetailView(type: type)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "xmark")
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    Button {
                        dismiss()
                    } label: {
                        Text("닫기")
                            .font(.subheadline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, DesignSystem.Spacing.md)
                            .background(DesignSystem.Colors.accent)
                            .foregroundColor(.white)
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                            .padding(.horizontal, DesignSystem.Spacing.lg)
                            .padding(.vertical, DesignSystem.Spacing.sm)
                    }
                }
        }
    }
}

#Preview {
    PolicyModal(type: .terms)
}
