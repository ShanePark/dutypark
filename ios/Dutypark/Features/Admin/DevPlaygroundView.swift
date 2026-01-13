import SwiftUI

struct DevPlaygroundView: View {
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var isExpanded = false

    var body: some View {
        ZStack {
            (colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgSecondary)
                .ignoresSafeArea()

            if authManager.currentUser?.isAdmin != true {
                EmptyStateView(
                    icon: "lock.slash",
                    title: "접근 권한이 없습니다",
                    message: "관리자 전용 기능입니다."
                )
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        AdminNavigationGrid(current: .dev)

                        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                            Text("개발 플레이그라운드")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(textPrimary)

                            Text("컴포넌트를 테스트하고 비교해볼 수 있는 공간입니다.")
                                .font(.subheadline)
                                .foregroundColor(textSecondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 0) {
                            Button {
                                isExpanded.toggle()
                            } label: {
                                HStack {
                                    Text("예제 섹션")
                                        .font(.headline)
                                        .foregroundColor(textPrimary)
                                    Spacer()
                                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                                        .foregroundColor(textMuted)
                                }
                            }
                            .padding(DesignSystem.Spacing.lg)

                            if isExpanded {
                                Divider()
                                VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                                    Text("여기에 테스트할 컴포넌트를 추가하세요.")
                                        .font(.subheadline)
                                        .foregroundColor(textSecondary)

                                    Text("<YourComponent />")
                                        .font(.caption)
                                        .padding(DesignSystem.Spacing.md)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                                        .cornerRadius(DesignSystem.CornerRadius.sm)
                                }
                                .padding(DesignSystem.Spacing.lg)
                            }
                        }
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                        .cornerRadius(DesignSystem.CornerRadius.lg)
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }
            }
        }
        .navigationTitle("개발")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var textPrimary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary
    }

    private var textSecondary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary
    }

    private var textMuted: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted
    }
}

#Preview {
    DevPlaygroundView()
        .environmentObject(AuthManager.shared)
}
