import SwiftUI

struct AdminTeamListView: View {
    @StateObject private var viewModel = AdminTeamListViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var navigateTeamId: Int?
    @State private var navigateToTeam = false
    @State private var keyword = ""
    @State private var searchKeyword = ""
    @State private var showCreateTeamSheet = false

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
            } else if let error = viewModel.error, viewModel.teams.isEmpty, !viewModel.isLoading {
                ErrorView(
                    code: nil,
                    title: "팀 목록을 불러오지 못했습니다",
                    message: error,
                    actionTitle: "다시 시도"
                ) {
                    Task { await reload() }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        AdminNavigationGrid(current: .teams)

                        teamListSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await reload()
                }
            }

            if viewModel.isLoading && viewModel.teams.isEmpty {
                ProgressView()
            }

            if let navigateTeamId {
                NavigationLink(
                    destination: TeamManageView(teamId: navigateTeamId),
                    isActive: $navigateToTeam
                ) {
                    EmptyView()
                }
            }
        }
        .navigationTitle("팀 관리")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showCreateTeamSheet) {
            CreateTeamSheet(viewModel: viewModel) { teamId in
                navigateTeamId = teamId
                navigateToTeam = true
            }
        }
        .task {
            await reload()
        }
        .onChange(of: authManager.currentUser?.isAdmin) { _, _ in
            Task { await reload() }
        }
        .onChange(of: navigateToTeam) { _, isActive in
            if !isActive {
                navigateTeamId = nil
            }
        }
    }

    private var teamListSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("팀 목록")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                HStack {
                    if !searchKeyword.isEmpty {
                        Text("[\(searchKeyword)]")
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.accent)
                    }
                    Text("총 \(viewModel.totalElements)개의 팀이 있습니다")
                        .font(.caption)
                        .foregroundColor(textSecondary)
                }

                HStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(textMuted)
                        TextField("팀 검색...", text: $keyword)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(textPrimary)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await searchTeams() }
                            }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                    Button("검색") {
                        Task { await searchTeams() }
                    }
                    .font(.subheadline)
                    .foregroundColor(textPrimary)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgCard)
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                    Button {
                        showCreateTeamSheet = true
                    } label: {
                        HStack(spacing: DesignSystem.Spacing.xs) {
                            Image(systemName: "plus")
                            Text("추가")
                        }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(Color.blue)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            .padding(DesignSystem.Spacing.lg)

            Divider()

            VStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.isLoading && !viewModel.teams.isEmpty {
                    ProgressView()
                        .padding()
                }

                ForEach(viewModel.teams.indices, id: \.self) { index in
                    let team = viewModel.teams[index]
                    NavigationLink(destination: TeamManageView(teamId: team.id)) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: DesignSystem.Spacing.xs) {
                                    Image(systemName: "building.2")
                                        .font(.caption)
                                        .foregroundColor(textMuted)
                                    Text(team.name)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(textPrimary)
                                }

                                Text(team.description)
                                    .font(.caption)
                                    .foregroundColor(textSecondary)
                                    .lineLimit(2)
                            }

                            Spacer()

                            HStack(spacing: 4) {
                                Image(systemName: "person.2")
                                    .font(.caption2)
                                Text("\(team.memberCount)")
                                    .font(.caption)
                            }
                            .foregroundColor(textSecondary)
                        }
                        .padding(DesignSystem.Spacing.lg)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                        .cornerRadius(DesignSystem.CornerRadius.md)
                    }
                    .buttonStyle(.plain)
                }

                if viewModel.teams.isEmpty && !viewModel.isLoading {
                    Text("검색 결과가 없습니다")
                        .font(.subheadline)
                        .foregroundColor(textMuted)
                        .padding(.vertical, DesignSystem.Spacing.xl)
                }
            }
            .padding(DesignSystem.Spacing.lg)

            if viewModel.totalPages > 1 {
                Divider()

                HStack {
                    Text("페이지 \(viewModel.currentPage + 1) / \(viewModel.totalPages)")
                        .font(.caption)
                        .foregroundColor(textSecondary)

                    Spacer()

                    HStack(spacing: DesignSystem.Spacing.sm) {
                        Button {
                            Task { await goToPage(viewModel.currentPage - 1) }
                        } label: {
                            Image(systemName: "chevron.left")
                        }
                        .disabled(viewModel.currentPage == 0)

                        Button {
                            Task { await goToPage(viewModel.currentPage + 1) }
                        } label: {
                            Image(systemName: "chevron.right")
                        }
                        .disabled(viewModel.currentPage >= viewModel.totalPages - 1)
                    }
                    .foregroundColor(textSecondary)
                }
                .padding(DesignSystem.Spacing.lg)
            }
        }
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
        .cornerRadius(DesignSystem.CornerRadius.lg)
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

    private func reload() async {
        guard authManager.currentUser?.isAdmin == true else { return }
        await viewModel.loadTeams(keyword: searchKeyword, page: viewModel.currentPage)
    }

    private func searchTeams() async {
        searchKeyword = keyword
        await viewModel.loadTeams(keyword: searchKeyword, page: 0)
    }

    private func goToPage(_ page: Int) async {
        guard page >= 0, page < viewModel.totalPages else { return }
        await viewModel.loadTeams(keyword: searchKeyword, page: page)
    }
}

#Preview {
    AdminTeamListView()
        .environmentObject(AuthManager.shared)
}
