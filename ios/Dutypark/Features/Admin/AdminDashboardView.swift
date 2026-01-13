import SwiftUI

struct AdminDashboardView: View {
    @StateObject private var viewModel = AdminDashboardViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.colorScheme) private var colorScheme
    @State private var searchKeyword = ""
    @State private var showPasswordSheet = false
    @State private var selectedMember: AdminMemberDto?
    @State private var expandedMemberIds: Set<Int> = []

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
            } else if let error = viewModel.error, viewModel.members.isEmpty, !viewModel.isLoading {
                ErrorView(
                    code: nil,
                    title: "데이터를 불러오지 못했습니다",
                    message: error,
                    actionTitle: "다시 시도"
                ) {
                    Task { await reload() }
                }
                .padding()
            } else {
                ScrollView {
                    VStack(spacing: DesignSystem.Spacing.lg) {
                        AdminNavigationGrid(current: .members)

                        statsSection

                        memberSection
                    }
                    .padding(.horizontal, DesignSystem.Spacing.lg)
                    .padding(.vertical, DesignSystem.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .refreshable {
                    await reload()
                }
            }

            if viewModel.isLoading && viewModel.members.isEmpty {
                ProgressView()
            }
        }
        .navigationTitle("관리자")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showPasswordSheet) {
            if let member = selectedMember {
                AdminPasswordSheet(viewModel: viewModel, member: member)
            }
        }
        .task {
            await reload()
        }
        .onChange(of: authManager.currentUser?.isAdmin) { _, _ in
            Task { await reload() }
        }
    }

    private var statsSection: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: DesignSystem.Spacing.md), count: 2), spacing: DesignSystem.Spacing.md) {
            statCard(icon: "person.3", title: "등록 회원", value: "\(viewModel.totalElements)")
            statCard(icon: "building.2", title: "등록 팀", value: "\(activeTeamsCount)")
            statCard(icon: "key", title: "활성 토큰", value: "\(viewModel.tokens.count)")
            statCard(icon: "clock", title: "오늘 접속", value: "\(todayLoginsCount)")
        }
    }

    private var memberSection: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: DesignSystem.Spacing.md) {
                Text("회원 관리")
                    .font(.headline)
                    .foregroundColor(textPrimary)

                HStack(spacing: DesignSystem.Spacing.sm) {
                    HStack(spacing: DesignSystem.Spacing.xs) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(textMuted)
                        TextField("회원 검색...", text: $searchKeyword)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .foregroundColor(textPrimary)
                            .submitLabel(.search)
                            .onSubmit {
                                Task { await searchMembers() }
                            }
                    }
                    .padding(DesignSystem.Spacing.md)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary)
                    .cornerRadius(DesignSystem.CornerRadius.sm)

                    Button("검색") {
                        Task { await searchMembers() }
                    }
                    .font(.subheadline)
                    .foregroundColor(.white)
                    .padding(.horizontal, DesignSystem.Spacing.md)
                    .padding(.vertical, DesignSystem.Spacing.sm)
                    .background(DesignSystem.Colors.accent)
                    .cornerRadius(DesignSystem.CornerRadius.sm)
                }
            }
            .padding(DesignSystem.Spacing.lg)

            Divider()

            VStack(spacing: DesignSystem.Spacing.md) {
                if viewModel.isLoading && !viewModel.members.isEmpty {
                    ProgressView()
                        .padding()
                }

                ForEach(viewModel.members) { member in
                    VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
                        HStack(spacing: DesignSystem.Spacing.md) {
                            ProfileAvatar(
                                memberId: member.id,
                                name: member.name,
                                hasProfilePhoto: member.hasProfilePhoto ?? false,
                                profilePhotoVersion: member.profilePhotoVersion,
                                size: 42
                            )

                            VStack(alignment: .leading, spacing: 4) {
                                Text(member.name)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(textPrimary)

                                Text(member.tokens.isEmpty ? "활성 세션 없음" : "\(member.tokens.count)개의 활성 세션")
                                    .font(.caption)
                                    .foregroundColor(textSecondary)
                            }

                            Spacer()

                            Button("비밀번호 변경") {
                                selectedMember = member
                                showPasswordSheet = true
                            }
                            .font(.caption)
                            .foregroundColor(DesignSystem.Colors.warning)
                            .padding(.horizontal, DesignSystem.Spacing.md)
                            .padding(.vertical, DesignSystem.Spacing.xs)
                            .background(DesignSystem.Colors.warning.opacity(0.12))
                            .cornerRadius(DesignSystem.CornerRadius.sm)
                        }

                        if !member.tokens.isEmpty {
                            DisclosureGroup(
                                isExpanded: expandedBinding(for: member.id),
                                content: {
                                    VStack(spacing: DesignSystem.Spacing.sm) {
                                        ForEach(member.tokens) { token in
                                            SessionCardView(token: token) {
                                                Task { _ = await viewModel.revokeToken(token.id) }
                                            }
                                        }
                                    }
                                    .padding(.top, DesignSystem.Spacing.sm)
                                },
                                label: {
                                    Text("세션 보기")
                                        .font(.caption)
                                        .foregroundColor(textSecondary)
                                }
                            )
                        }
                    }
                    .padding(DesignSystem.Spacing.lg)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
                    .cornerRadius(DesignSystem.CornerRadius.md)
                }

                if viewModel.members.isEmpty && !viewModel.isLoading {
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
                    let startIndex = max(0, viewModel.currentPage * viewModel.pageSize + 1)
                    let endIndex = min((viewModel.currentPage + 1) * viewModel.pageSize, viewModel.totalElements)

                    Text("총 \(viewModel.totalElements)명 중 \(startIndex)-\(endIndex)")
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

                        Text("\(viewModel.currentPage + 1) / \(viewModel.totalPages)")
                            .font(.caption)
                            .foregroundColor(textSecondary)

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

    private var activeTeamsCount: Int {
        Set(viewModel.members.compactMap { $0.teamId }).count
    }

    private var todayLoginsCount: Int {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        let today = formatter.string(from: Date())
        return viewModel.tokens.filter { $0.lastUsed?.hasPrefix(today) == true }.count
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

    private func statCard(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: DesignSystem.Spacing.sm) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(textMuted)
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(textPrimary)
            Text(title)
                .font(.caption)
                .foregroundColor(textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignSystem.Spacing.lg)
        .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
        .cornerRadius(DesignSystem.CornerRadius.md)
        .overlay(
            RoundedRectangle(cornerRadius: DesignSystem.CornerRadius.md)
                .stroke(colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary, lineWidth: 1)
        )
    }

    private func expandedBinding(for memberId: Int) -> Binding<Bool> {
        Binding(
            get: { expandedMemberIds.contains(memberId) },
            set: { isExpanded in
                if isExpanded {
                    expandedMemberIds.insert(memberId)
                } else {
                    expandedMemberIds.remove(memberId)
                }
            }
        )
    }

    private func reload() async {
        guard authManager.currentUser?.isAdmin == true else { return }
        await viewModel.loadDashboard(keyword: searchKeyword, page: viewModel.currentPage)
    }

    private func searchMembers() async {
        await viewModel.loadDashboard(keyword: searchKeyword, page: 0)
    }

    private func goToPage(_ page: Int) async {
        guard page >= 0, page < viewModel.totalPages else { return }
        await viewModel.loadDashboard(keyword: searchKeyword, page: page)
    }
}

#Preview {
    AdminDashboardView()
        .environmentObject(AuthManager.shared)
}
