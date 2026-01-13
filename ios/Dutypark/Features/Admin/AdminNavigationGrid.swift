import SwiftUI

enum AdminSection {
    case members
    case teams
    case dev
}

struct AdminNavigationGrid: View {
    let current: AdminSection
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.md), count: 2), spacing: DesignSystem.Spacing.md) {
            navigationCard(title: "회원 관리", systemImage: "person.3", isActive: current == .members) {
                AdminDashboardView()
            }

            navigationCard(title: "팀 관리", systemImage: "building.2", isActive: current == .teams) {
                AdminTeamListView()
            }

            navigationCard(title: "개발", systemImage: "hammer", isActive: current == .dev) {
                DevPlaygroundView()
            }

            Link(destination: apiDocsURL()) {
                cardLabel(title: "API 문서", systemImage: "doc.text", isActive: false, showsExternal: true)
            }
        }
    }

    private func navigationCard<Destination: View>(
        title: String,
        systemImage: String,
        isActive: Bool,
        destination: @escaping () -> Destination
    ) -> some View {
        Group {
            if isActive {
                cardLabel(title: title, systemImage: systemImage, isActive: true, showsExternal: false)
            } else {
                NavigationLink(destination: destination()) {
                    cardLabel(title: title, systemImage: systemImage, isActive: false, showsExternal: false)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func cardLabel(title: String, systemImage: String, isActive: Bool, showsExternal: Bool) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            HStack(spacing: DesignSystem.Spacing.xs) {
                Image(systemName: systemImage)
                    .font(.title3)
                if showsExternal {
                    Image(systemName: "arrow.up.right.square")
                        .font(.caption)
                        .foregroundColor(colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted)
                }
            }
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity, minHeight: 72, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(isActive ? DesignSystem.Colors.accent.opacity(0.15) : (colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard))
        .foregroundColor(isActive ? DesignSystem.Colors.accent : (colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary))
        .cornerRadius(DesignSystem.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(isActive ? DesignSystem.Colors.accent : (colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary), lineWidth: 1)
        )
    }

    private func apiDocsURL() -> URL {
        #if DEBUG
        return URL(string: "http://localhost:8080/docs/index.html")!
        #else
        return URL(string: "https://duty.park/docs/index.html")!
        #endif
    }
}

#Preview {
    NavigationStack {
        AdminNavigationGrid(current: .members)
            .padding()
    }
}
