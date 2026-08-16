import SwiftUI

struct AdminRootView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.openURL) private var openURL
    @StateObject private var memberModel: AdminMemberListViewModel
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var destination: AdminRootDestination?
    let onOpenCalendar: (MemberID) -> Void
    private let repository: any AdminRepositoryProtocol

    init(
        repository: (any AdminRepositoryProtocol)? = nil,
        onOpenCalendar: @escaping (MemberID) -> Void
    ) {
        let resolvedRepository: any AdminRepositoryProtocol
#if DEBUG
        if let repository {
            resolvedRepository = repository
        } else if ProcessInfo.processInfo.arguments.contains("-ui-testing-admin-visual-fixture") {
            resolvedRepository = AdminVisualFixtureRepository()
        } else {
            resolvedRepository = AdminRepository()
        }
#else
        resolvedRepository = repository ?? AdminRepository()
#endif
        self.repository = resolvedRepository
        _memberModel = StateObject(
            wrappedValue: AdminMemberListViewModel(repository: resolvedRepository)
        )
        self.onOpenCalendar = onOpenCalendar
    }

    var body: some View {
        Group {
            if isAdmin {
                List {
                    Section {
                        LazyVGrid(columns: dashboardColumns, spacing: DPSpacing.small) {
                            AdminTopTile(
                                title: AdminLocalization.string("admin.nav.members"),
                                systemImage: "person.3.fill",
                                color: DPColor.accent,
                                isSelected: true
                            )
                            .accessibilityIdentifier("admin.tile.members")

                            Button {
                                destination = .teams
                            } label: {
                                AdminTopTile(
                                    title: AdminLocalization.string("admin.nav.teams"),
                                    systemImage: "building.2.fill",
                                    color: DPColor.success
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("admin.tile.teams")

                            Button {
                                destination = .development
                            } label: {
                                AdminTopTile(
                                    title: AdminLocalization.string("admin.nav.development"),
                                    systemImage: "chevron.left.forwardslash.chevron.right",
                                    color: DPColor.warning
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityIdentifier("admin.tile.development")

                            Button {
                                openURL(AdminWebDestination.apiDocumentationURL())
                            } label: {
                                AdminTopTile(
                                    title: AdminLocalization.string("admin.nav.apiDocumentation"),
                                    systemImage: "doc.text.fill",
                                    color: DPColor.surfaceStrong
                                )
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(AdminLocalization.string("admin.nav.apiDocumentation"))
                            .accessibilityHint(
                                AdminLocalization.string("admin.nav.apiDocumentation.externalHint")
                            )
                            .accessibilityIdentifier("admin.tile.apiDocumentation")
                        }
                        .padding(.vertical, DPSpacing.extraSmall)
                    }
                    .listRowInsets(.init(
                        top: 0,
                        leading: DPSpacing.compact,
                        bottom: 0,
                        trailing: DPSpacing.compact
                    ))
                    .listRowBackground(Color.clear)

                    Section {
                        LazyVGrid(columns: dashboardColumns, spacing: DPSpacing.small) {
                            ForEach(Array(summaryCards.enumerated()), id: \.offset) { _, card in
                                AdminSummaryCard(
                                    title: AdminLocalization.string(card.key),
                                    value: card.value
                                )
                            }
                        }
                        .padding(.vertical, DPSpacing.extraSmall)
                    }
                    .listRowInsets(.init(
                        top: 0,
                        leading: DPSpacing.compact,
                        bottom: 0,
                        trailing: DPSpacing.compact
                    ))
                    .listRowBackground(Color.clear)

                    Section(AdminLocalization.string("admin.members.title")) {
                        if memberModel.isLoading && memberModel.members.isEmpty {
                            ProgressView(AdminLocalization.string("admin.common.loading"))
                                .frame(maxWidth: .infinity)
                        } else if memberModel.loadFailed && memberModel.members.isEmpty {
                            Button {
                                Task { await memberModel.load() }
                            } label: {
                                Label(
                                    AdminLocalization.string("admin.members.loadFailed"),
                                    systemImage: "arrow.clockwise"
                                )
                            }
                        } else if memberModel.members.isEmpty {
                            ContentUnavailableView(
                                AdminLocalization.string("admin.members.empty"),
                                systemImage: "person.crop.circle.badge.questionmark"
                            )
                            .accessibilityIdentifier("admin.members.empty")
                        } else {
                            ForEach(memberModel.members) { member in
                                NavigationLink {
                                    AdminMemberDetailView(
                                        member: member,
                                        model: memberModel,
                                        onOpenCalendar: onOpenCalendar
                                    )
                                } label: {
                                    AdminMemberRow(member: member)
                                }
                            }
                        }
                    }

                    if memberModel.totalPages > 1 {
                        Section {
                            AdminPaginationFooter(
                                page: memberModel.page,
                                totalPages: memberModel.totalPages,
                                onPrevious: { Task { await memberModel.movePage(by: -1) } },
                                onNext: { Task { await memberModel.movePage(by: 1) } }
                            )
                        }
                    }
                }
                .listStyle(.insetGrouped)
                .refreshable { await memberModel.load() }
                .searchable(
                    text: $searchText,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: AdminLocalization.string("admin.members.search")
                )
                .onChange(of: searchText) { _, newValue in
                    searchTask?.cancel()
                    let keyword = AdminMemberSearchPolicy.normalized(newValue)
                    searchTask = Task {
                        try? await Task.sleep(for: AdminMemberSearchPolicy.debounce)
                        guard !Task.isCancelled else { return }
                        await memberModel.search(keyword)
                    }
                }
                .task { await memberModel.load() }
                .onDisappear { searchTask?.cancel() }
            } else {
                ContentUnavailableView(
                    AdminLocalization.string("admin.access.title"),
                    systemImage: "lock.shield",
                    description: Text(AdminLocalization.string("admin.access.message"))
                )
            }
        }
        .navigationTitle(AdminLocalization.string("admin.menu.title"))
        .navigationBarTitleDisplayMode(.large)
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .teams:
                AdminTeamListView(
                    model: AdminTeamListViewModel(repository: repository)
                )
            case .development:
                AdminAuthenticatedWebView(
                    path: destination.embeddedWebPath ?? "admin/dev",
                    title: AdminLocalization.string("admin.nav.development")
                )
            }
        }
        .accessibilityIdentifier("screen.admin")
    }

    private var isAdmin: Bool {
        guard case .authenticated(let member) = session.state else { return false }
        return member.isAdmin
    }

    private var dashboardColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 140), spacing: DPSpacing.small)]
    }

    private var summaryCards: [(key: String, value: Int)] {
        let stats = AdminDashboardStatsPresentation(
            totalMembers: memberModel.totalElements,
            loadedMembers: memberModel.members,
            sessions: memberModel.sessions,
            today: AdminDashboardStatsPresentation.todayString()
        )
        return zip(AdminDashboardStatsPresentation.localizationKeys, stats.values)
            .map { (key: $0.0, value: $0.1) }
    }
}

private struct AdminTopTile: View {
    let title: String
    let systemImage: String
    let color: Color
    var isSelected = false

    var body: some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(isSelected ? AdminTopTilePresentation.selectedForeground : color)
                .frame(width: 30, height: 30)
                .background(
                    (isSelected ? Color.white.opacity(0.16) : color.opacity(0.12)),
                    in: RoundedRectangle(cornerRadius: DPRadius.small)
                )
            Text(title)
                .font(DPTypography.label)
                .foregroundStyle(
                    isSelected ? AdminTopTilePresentation.selectedForeground : DPColor.textPrimary
                )
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
        }
        .padding(DPSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(
            isSelected ? AdminTopTilePresentation.selectedBackground : DPColor.backgroundSecondary,
            in: RoundedRectangle(cornerRadius: DPRadius.standard)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(color.opacity(isSelected ? 0 : 0.18), lineWidth: 1)
        }
    }
}

private struct AdminSummaryCard: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text(value.formatted())
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Text(title)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(DPSpacing.small)
        .frame(maxWidth: .infinity, minHeight: 68, alignment: .leading)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
    }
}

private struct AdminMemberRow: View {
    let member: AdminMemberDTO

    var body: some View {
        HStack(spacing: DPSpacing.compact) {
            AdminMemberAvatar(
                memberID: member.id,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto,
                version: member.profilePhotoVersion,
                size: 44
            )
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                Text(member.email ?? AdminLocalization.string("admin.members.noEmail"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
                if let teamName = member.teamName {
                    Label(teamName, systemImage: "building.2")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textSecondary)
                }
            }
            Spacer(minLength: DPSpacing.extraSmall)
            Text(AdminMemberSessionCountPresentation.text(count: member.tokens.count))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .frame(minHeight: 60)
        .accessibilityIdentifier("admin.member.\(member.id)")
    }
}

private struct AdminMemberAvatar: View {
    let memberID: MemberID
    let name: String
    let hasProfilePhoto: Bool
    let version: Int64
    let size: CGFloat

    var body: some View {
        Group {
            if hasProfilePhoto {
                AsyncImage(url: AdminMemberAvatarPresentation.url(memberID: memberID, version: version)) { phase in
                    if let image = phase.image {
                        image.resizable().scaledToFill()
                    } else {
                        fallback
                    }
                }
            } else {
                fallback
            }
        }
        .frame(width: size, height: size)
        .clipShape(Circle())
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityIdentifier("admin.member.avatar.\(memberID)")
    }

    private var fallback: some View {
        ZStack {
            DPColor.accent.opacity(0.14)
            Text(String(name.prefix(1)))
                .font(.system(size: size * 0.38, weight: .semibold))
                .foregroundStyle(DPColor.accent)
        }
    }
}

nonisolated enum AdminTopTilePresentation {
    static let selectedBackground = DPColor.surfaceStrong
    static let selectedForeground = DPColor.textOnDark
}

nonisolated enum AdminRootDestination: String, CaseIterable, Hashable, Identifiable, Sendable {
    case teams
    case development

    var id: Self { self }

    var embeddedWebPath: String? {
        switch self {
        case .teams: nil
        case .development: "admin/dev"
        }
    }
}

nonisolated enum AdminRootNavigationPresentation {
    static let tileKeys = [
        "admin.nav.members",
        "admin.nav.teams",
        "admin.nav.development",
        "admin.nav.apiDocumentation",
    ]
}

nonisolated enum AdminMemberSearchPolicy {
    static let debounce: Duration = .milliseconds(300)

    static func normalized(_ keyword: String) -> String {
        keyword.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

nonisolated struct AdminDashboardStatsPresentation: Equatable, Sendable {
    static let localizationKeys = [
        "admin.dashboard.totalMembers",
        "admin.dashboard.teams",
        "admin.dashboard.activeSessions",
        "admin.dashboard.todayLogins",
    ]

    let totalMembers: Int64
    let teamCount: Int
    let activeSessionCount: Int
    let todayLoginCount: Int

    var values: [Int] {
        [Int(totalMembers), teamCount, activeSessionCount, todayLoginCount]
    }

    init(
        totalMembers: Int64,
        loadedMembers: [AdminMemberDTO],
        sessions: [SettingsRefreshToken],
        today: String
    ) {
        self.totalMembers = totalMembers
        teamCount = Set(loadedMembers.compactMap(\.teamId)).count
        activeSessionCount = sessions.count
        todayLoginCount = sessions.count { $0.lastUsed?.hasPrefix(today) == true }
    }

    static func todayString(
        date: Date = Date(),
        calendar: Calendar = .current
    ) -> String {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        return String(
            format: "%04d-%02d-%02d",
            components.year ?? 0,
            components.month ?? 0,
            components.day ?? 0
        )
    }
}

nonisolated enum AdminMemberAvatarPresentation {
    static func url(memberID: MemberID, version: Int64) -> URL {
        AppConfiguration.apiBaseURL
            .appending(path: "members/\(memberID)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: version.formatted()),
            ])
    }
}

nonisolated enum AdminMemberDetailPresentation {
    static func dateText(
        _ value: LocalDateTimeValue?,
        locale: Locale = AppLocalization.locale,
        timeZone: TimeZone = .current
    ) -> String {
        guard let value, let date = parse(value.rawValue, timeZone: timeZone) else { return "-" }
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    static func roleKeys(
        serviceAdmin: Bool,
        teamAdmin: Bool,
        teamManager: Bool,
        auxiliaryAccount: Bool
    ) -> [String] {
        var keys: [String] = []
        if serviceAdmin { keys.append("admin.members.role.serviceAdmin") }
        if teamAdmin { keys.append("admin.members.role.teamAdmin") }
        if teamManager { keys.append("admin.members.role.teamManager") }
        if auxiliaryAccount { keys.append("admin.members.role.auxiliary") }
        if keys.isEmpty { keys.append("admin.members.role.member") }
        return keys
    }

    static func visibilityKey(_ visibility: Visibility) -> String {
        switch visibility {
        case .publicAccess: "admin.members.visibility.public"
        case .friends: "admin.members.visibility.friends"
        case .family: "admin.members.visibility.family"
        case .privateAccess: "admin.members.visibility.private"
        case .unknown: "admin.members.visibility.unknown"
        }
    }

    private static func parse(_ rawValue: String, timeZone: TimeZone) -> Date? {
        for format in ["yyyy-MM-dd'T'HH:mm:ss.SSSSSS", "yyyy-MM-dd'T'HH:mm:ss.SSS", "yyyy-MM-dd'T'HH:mm:ss"] {
            let formatter = DateFormatter()
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.timeZone = timeZone
            formatter.dateFormat = format
            if let date = formatter.date(from: rawValue) { return date }
        }
        return nil
    }
}

nonisolated enum AdminMemberSessionCountPresentation {
    static func text(count: Int, locale: Locale = AppLocalization.locale) -> String {
        guard count > 0 else {
            return AppLocalization.string(
                "admin.members.sessions.empty",
                table: "Admin",
                locale: locale
            )
        }

        return String(
            format: AppLocalization.string(
                "admin.members.sessions.count",
                table: "Admin",
                locale: locale
            ),
            locale: locale,
            count
        )
    }
}

nonisolated struct AdminMemberDetailMetricsPresentation: Equatable, Sendable {
    let directCreatedScheduleCount: Int64
    let upcomingScheduleCount: Int64
    let taggedScheduleCount: Int64
    let pendingTodoCount: Int64
    let inProgressTodoCount: Int64
    let doneTodoCount: Int64
    let overdueTodoCount: Int64
    let dueTodayTodoCount: Int64
    let totalDDayCount: Int
    let publicDDayCount: Int
    let privateDDayCount: Int
    let receivedFriendRequestCount: Int64
    let sentFriendRequestCount: Int64

    var scheduleCounts: [Int64] {
        [directCreatedScheduleCount, upcomingScheduleCount, taggedScheduleCount]
    }

    var todoCounts: [Int64] {
        [pendingTodoCount, inProgressTodoCount, doneTodoCount, overdueTodoCount, dueTodayTodoCount]
    }

    var dDayCounts: [Int] { [totalDDayCount, publicDDayCount, privateDDayCount] }
    var friendRequestCounts: [Int64] { [receivedFriendRequestCount, sentFriendRequestCount] }

    init(
        totalScheduleCount: Int64,
        upcomingScheduleCount: Int64,
        taggedScheduleCount: Int64,
        todoCount: Int64,
        inProgressTodoCount: Int64,
        doneTodoCount: Int64,
        overdueTodoCount: Int64,
        dueTodayTodoCount: Int64,
        dDayPrivacy: [Bool],
        pendingReceivedFriendRequestCount: Int64,
        pendingSentFriendRequestCount: Int64
    ) {
        directCreatedScheduleCount = totalScheduleCount
        self.upcomingScheduleCount = upcomingScheduleCount
        self.taggedScheduleCount = taggedScheduleCount
        pendingTodoCount = todoCount
        self.inProgressTodoCount = inProgressTodoCount
        self.doneTodoCount = doneTodoCount
        self.overdueTodoCount = overdueTodoCount
        self.dueTodayTodoCount = dueTodayTodoCount

        let privateCount = dDayPrivacy.count(where: { $0 })
        totalDDayCount = dDayPrivacy.count
        publicDDayCount = dDayPrivacy.count - privateCount
        privateDDayCount = privateCount
        receivedFriendRequestCount = pendingReceivedFriendRequestCount
        sentFriendRequestCount = pendingSentFriendRequestCount
    }

    init(detail: AdminMemberDetailDTO) {
        self.init(
            totalScheduleCount: detail.totalScheduleCount,
            upcomingScheduleCount: detail.upcomingScheduleCount,
            taggedScheduleCount: detail.taggedScheduleCount,
            todoCount: detail.todoCount,
            inProgressTodoCount: detail.inProgressTodoCount,
            doneTodoCount: detail.doneTodoCount,
            overdueTodoCount: detail.overdueTodoCount,
            dueTodayTodoCount: detail.dueTodayTodoCount,
            dDayPrivacy: detail.dDays.map(\.isPrivate),
            pendingReceivedFriendRequestCount: detail.pendingReceivedFriendRequestCount,
            pendingSentFriendRequestCount: detail.pendingSentFriendRequestCount
        )
    }
}

private struct AdminMemberDetailView: View {
    let member: AdminMemberDTO
    @ObservedObject var model: AdminMemberListViewModel
    let onOpenCalendar: (MemberID) -> Void
    @State private var detail: AdminMemberDetailDTO?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showsPasswordSheet = false
    @State private var passwordModalState = AdminModalInteractionState()
    @State private var showsPasswordDiscardConfirmation = false
    @State private var sessionConfirmation: AdminSessionRevokeConfirmation?
    @State private var isRevokingSession = false
    @State private var operationMessage: String?

    var body: some View {
        List {
            Section {
                identityHeader
            }

            if isLoading {
                Section { ProgressView(AdminLocalization.string("admin.common.loading")) }
            } else if loadFailed {
                Section {
                    Button(AdminLocalization.string("admin.common.retry")) {
                        Task { await loadDetail() }
                    }
                }
            } else if let detail {
                detailSections(detail)
            }

            Section(AdminLocalization.string("admin.members.sessions")) {
                let sessions = model.sessions.filter { $0.memberId == member.id }
                if sessions.isEmpty {
                    Text(AdminLocalization.string("admin.members.sessions.empty"))
                        .foregroundStyle(DPColor.textMuted)
                } else {
                    ForEach(sessions) { token in
                        AdminSessionRow(token: token) {
                            sessionConfirmation = AdminSessionRevokeConfirmation(token: token)
                        }
                    }
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .fullScreenCover(isPresented: $showsPasswordSheet) {
            DPModalOverlay(
                onDismiss: { showsPasswordSheet = false },
                canDismiss: passwordModalState.allowsDismiss,
                onDismissRequest: { _ in requestPasswordModalDismiss() }
            ) { availableSize, _ in
                AdminPasswordChangeModal(
                    member: member,
                    model: model,
                    maximumHeight: availableSize.height,
                    interactionState: $passwordModalState,
                    requestDismiss: requestPasswordModalDismiss
                ) {
                    operationMessage = AdminLocalization.string("admin.members.passwordChanged")
                    showsPasswordSheet = false
                }
            }
            .alert(
                AdminLocalization.string("admin.common.discard.title"),
                isPresented: $showsPasswordDiscardConfirmation
            ) {
                Button(AdminLocalization.string("admin.common.discard.action"), role: .destructive) {
                    showsPasswordSheet = false
                }
                Button(AdminLocalization.string("admin.common.discard.continue"), role: .cancel) {}
            } message: {
                Text(AdminLocalization.string("admin.common.discard.message"))
            }
        }
        .fullScreenCover(item: $sessionConfirmation) { confirmation in
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { sessionConfirmation = nil },
                canDismiss: !isRevokingSession
            ) { availableSize, dismiss in
                DPConfirmationPanel(
                    title: confirmation.title,
                    message: confirmation.message,
                    confirmTitle: AdminLocalization.string("admin.members.revokeSession.action"),
                    cancelTitle: AdminLocalization.string("admin.common.cancel"),
                    isDestructive: true,
                    isWorking: isRevokingSession,
                    maximumHeight: availableSize.height,
                    cancel: dismiss,
                    confirm: { revokeSession(confirmation, dismiss: dismiss) }
                )
            }
            .interactiveDismissDisabled(isRevokingSession)
        }
        .alert(
            AdminLocalization.string("admin.common.notice"),
            isPresented: Binding(
                get: { operationMessage != nil },
                set: { if !$0 { operationMessage = nil } }
            )
        ) {
            Button(AdminLocalization.string("admin.common.ok"), role: .cancel) {}
        } message: {
            Text(operationMessage ?? "")
        }
    }

    @ViewBuilder
    private func detailSections(_ detail: AdminMemberDetailDTO) -> some View {
        let metrics = AdminMemberDetailMetricsPresentation(detail: detail)

        Section(AdminLocalization.string("admin.members.basicInfo")) {
            LabeledContent(AdminLocalization.string("admin.members.email"), value: detail.email ?? "-")
            LabeledContent(AdminLocalization.string("admin.members.team"), value: detail.teamName ?? AdminLocalization.string("admin.members.noTeam"))
            LabeledContent(
                AdminLocalization.string("admin.members.visibility"),
                value: AdminLocalization.string(AdminMemberDetailPresentation.visibilityKey(detail.calendarVisibility))
            )
            .accessibilityIdentifier("admin.member.metadata.visibility")
            LabeledContent(
                AdminLocalization.string("admin.members.created"),
                value: AdminMemberDetailPresentation.dateText(detail.createdDate)
            )
            LabeledContent(
                AdminLocalization.string("admin.members.lastModified"),
                value: AdminMemberDetailPresentation.dateText(detail.lastModifiedDate)
            )
            .accessibilityIdentifier("admin.member.metadata.lastModified")
            LabeledContent(
                AdminLocalization.string("admin.members.lastActive"),
                value: AdminMemberDetailPresentation.dateText(detail.lastActiveAt)
            )
        }

        Section(AdminLocalization.string("admin.members.accountStatus")) {
            LabeledContent(
                AdminLocalization.string("admin.members.authProviders"),
                value: listText(detail.authProviders)
            )
            LabeledContent(AdminLocalization.string("admin.members.hasPassword"), value: yesNo(detail.hasPassword))
            LabeledContent(AdminLocalization.string("admin.members.auxiliaryAccount"), value: yesNo(detail.auxiliaryAccount))
            LabeledContent(AdminLocalization.string("admin.members.activeSessions"), value: detail.activeSessionCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.pushEnabledSessions"), value: detail.pushEnabledSessionCount.formatted())
                .accessibilityIdentifier("admin.member.status.pushEnabledSessions")
            LabeledContent(AdminLocalization.string("admin.members.notifications"), value: detail.totalNotificationCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.unreadNotifications"), value: detail.unreadNotificationCount.formatted())
                .accessibilityIdentifier("admin.member.status.unreadNotifications")
        }

        Section(AdminLocalization.string("admin.members.scheduleSummary")) {
            LabeledContent(AdminLocalization.string("admin.members.directCreatedSchedules"), value: metrics.directCreatedScheduleCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.upcomingSchedules"), value: metrics.upcomingScheduleCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.taggedSchedules"), value: metrics.taggedScheduleCount.formatted())
        }

        Section(AdminLocalization.string("admin.members.todoSummary")) {
            LabeledContent(AdminLocalization.string("admin.members.totalTodos"), value: detail.totalTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.pendingTodos"), value: metrics.pendingTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.inProgressTodos"), value: metrics.inProgressTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.doneTodos"), value: metrics.doneTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.overdueTodos"), value: metrics.overdueTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.dueTodayTodos"), value: metrics.dueTodayTodoCount.formatted())
        }

        Section(AdminLocalization.string("admin.members.dDaySummary")) {
            LabeledContent(AdminLocalization.string("admin.members.totalDDays"), value: metrics.totalDDayCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.publicDDays"), value: metrics.publicDDayCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.privateDDays"), value: metrics.privateDDayCount.formatted())
        }

        Section(AdminLocalization.string("admin.members.relationships")) {
            LabeledContent(AdminLocalization.string("admin.members.friends"), value: detail.friendCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.family"), value: detail.familyCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.receivedFriendRequests"), value: metrics.receivedFriendRequestCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.sentFriendRequests"), value: metrics.sentFriendRequestCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.managers"), value: detail.managerCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.managerNames"), value: listText(detail.managerNames))
            LabeledContent(AdminLocalization.string("admin.members.managedMembers"), value: detail.managedMemberCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.managedMemberNames"), value: listText(detail.managedMemberNames))
        }
    }

    private var identityHeader: some View {
        VStack(spacing: DPSpacing.compact) {
            AdminMemberAvatar(
                memberID: member.id,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto,
                version: member.profilePhotoVersion,
                size: 76
            )

            VStack(spacing: 3) {
                Text(member.name)
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Text(AdminLocalization.format("admin.members.id", member.id))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                Text(member.email ?? AdminLocalization.string("admin.members.noEmail"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                Label(
                    member.teamName ?? AdminLocalization.string("admin.members.noTeam"),
                    systemImage: "building.2"
                )
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            }

            if let detail {
                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 92), spacing: DPSpacing.extraSmall)],
                    spacing: DPSpacing.extraSmall
                ) {
                    ForEach(
                        AdminMemberDetailPresentation.roleKeys(
                            serviceAdmin: detail.serviceAdmin,
                            teamAdmin: detail.teamAdmin,
                            teamManager: detail.teamManager,
                            auxiliaryAccount: detail.auxiliaryAccount
                        ),
                        id: \.self
                    ) { key in
                        Text(AdminLocalization.string(key))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.accent)
                            .padding(.horizontal, DPSpacing.small)
                            .padding(.vertical, DPSpacing.extraSmall)
                            .frame(maxWidth: .infinity)
                            .background(
                                DPColor.accent.opacity(0.12),
                                in: Capsule()
                            )
                    }
                }
                .accessibilityIdentifier("admin.member.roles")
            }

            HStack(spacing: DPSpacing.small) {
                Button {
                    onOpenCalendar(member.id)
                } label: {
                    Label(AdminLocalization.string("admin.members.openCalendar"), systemImage: "calendar")
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(DPSecondaryButtonStyle())

                Button {
                    passwordModalState = AdminModalInteractionState()
                    withoutPresentationAnimation { showsPasswordSheet = true }
                } label: {
                    Label(AdminLocalization.string("admin.members.changePassword"), systemImage: "key")
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .buttonStyle(DPSecondaryButtonStyle())
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DPSpacing.small)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("admin.member.identity")
    }

    private func yesNo(_ value: Bool) -> String {
        AdminLocalization.string(value ? "admin.common.yes" : "admin.common.no")
    }

    private func listText(_ values: [String]) -> String {
        values.isEmpty ? AdminLocalization.string("admin.members.none") : values.joined(separator: ", ")
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await model.memberDetail(id: member.id)
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }

    private func requestPasswordModalDismiss() {
        switch passwordModalState.dismissDecision {
        case .dismiss:
            showsPasswordSheet = false
        case .confirmDiscard:
            showsPasswordDiscardConfirmation = true
        case .blocked:
            break
        }
    }

    private func revokeSession(
        _ confirmation: AdminSessionRevokeConfirmation,
        dismiss: @escaping () -> Void
    ) {
        guard !isRevokingSession else { return }
        isRevokingSession = true

        Task {
            do {
                try await model.revokeSession(id: confirmation.token.id)
                operationMessage = AdminLocalization.string("admin.members.sessionRevoked")
            } catch {
                operationMessage = AdminLocalization.string("admin.members.operationFailed")
            }
            isRevokingSession = false
            dismiss()
        }
    }
}

private struct AdminSessionRow: View {
    let token: SettingsRefreshToken
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            HStack {
                Label(
                    token.userAgent?.device ?? AdminLocalization.string("admin.members.session.unknownDevice"),
                    systemImage: "iphone"
                )
                .font(DPTypography.label)
                Spacer()
                Button(role: .destructive, action: onRevoke) {
                    Image(systemName: "xmark.circle")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .accessibilityLabel(AdminLocalization.string("admin.members.revokeSession.action"))
                .accessibilityIdentifier("admin.member.session.revoke.\(token.id)")
            }
            Text(token.userAgent.map { "\($0.os) · \($0.browser)" } ?? "-")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            Text(token.lastUsed ?? token.createdDate ?? token.validUntil)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
        }
        .padding(.vertical, DPSpacing.extraSmall)
    }
}

nonisolated struct AdminSessionRevokeConfirmation: Identifiable, Equatable, Sendable {
    let token: SettingsRefreshToken

    var id: Int64 { token.id }
    var title: String { AdminLocalization.string("admin.members.revokeSession.title") }
    var message: String {
        AdminLocalization.format(
            "admin.members.revokeSession.message",
            token.memberName,
            token.userAgent?.device ?? AdminLocalization.string("admin.members.session.unknownDevice"),
            token.userAgent?.browser ?? "-",
            token.remoteAddr ?? "-"
        )
    }
}

nonisolated enum AdminModalDismissDecision: Equatable, Sendable {
    case dismiss
    case confirmDiscard
    case blocked
}

nonisolated struct AdminModalInteractionState: Equatable, Sendable {
    var isDirty = false
    var isSaving = false
    var isChecking = false

    var isWorking: Bool { isSaving || isChecking }
    var allowsDismiss: Bool { !isWorking }

    var dismissDecision: AdminModalDismissDecision {
        if isWorking { return .blocked }
        return isDirty ? .confirmDiscard : .dismiss
    }

    static func passwordIsDirty(
        password: String,
        confirmation: String,
        baselinePassword: String = "",
        baselineConfirmation: String = ""
    ) -> Bool {
        password != baselinePassword || confirmation != baselineConfirmation
    }

    static func teamIsDirty(
        name: String,
        description: String,
        baselineName: String = "",
        baselineDescription: String = ""
    ) -> Bool {
        name != baselineName || description != baselineDescription
    }
}

private struct AdminPasswordChangeModal: View {
    let member: AdminMemberDTO
    @ObservedObject var model: AdminMemberListViewModel
    let maximumHeight: CGFloat
    @Binding var interactionState: AdminModalInteractionState
    let requestDismiss: () -> Void
    let onSuccess: () -> Void
    @State private var password = ""
    @State private var confirmation = ""
    @State private var saveFailed = false
    @FocusState private var focusedField: Field?

    private enum Field { case password, confirmation }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            header
        } content: {
            formContent
        } footer: {
            footer
        }
        .onChange(of: password) { _, _ in updateDirtyState() }
        .onChange(of: confirmation) { _, _ in updateDirtyState() }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.compact) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AdminLocalization.string("admin.members.changePassword"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Text(member.name)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
            }
            Spacer()
            Button(action: requestDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(interactionState.isSaving)
            .accessibilityLabel(AdminLocalization.string("admin.common.cancel"))
        }
        .padding(.horizontal, DPSpacing.large)
        .frame(minHeight: 64)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            passwordField(
                AdminLocalization.string("admin.members.newPassword"),
                text: $password,
                field: .password
            )
            passwordField(
                AdminLocalization.string("admin.members.confirmPassword"),
                text: $confirmation,
                field: .confirmation
            )

            Text(AdminLocalization.string("admin.members.passwordHint"))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DPSpacing.large)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                Task { await save() }
            } label: {
                Group {
                    if interactionState.isSaving {
                        ProgressView().tint(DPColor.textOnDark)
                    } else {
                        Text(AdminLocalization.string("admin.common.save"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!isValid || interactionState.isSaving)

            Button(action: requestDismiss) {
                Text(AdminLocalization.string("admin.common.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(interactionState.isSaving)
        }
        .padding(DPSpacing.compact)
    }

    private func passwordField(
        _ title: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(title)
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textPrimary)
            SecureField(title, text: text)
                .textContentType(.newPassword)
                .focused($focusedField, equals: field)
                .submitLabel(field == .password ? .next : .done)
                .onSubmit {
                    focusedField = field == .password ? .confirmation : nil
                }
                .dpInputChrome(isFocused: focusedField == field)
                .disabled(interactionState.isSaving)
        }
    }

    private var isValid: Bool {
        (8...20).contains(password.count) && password == confirmation
    }

    private var validationMessage: String? {
        if saveFailed { return AdminLocalization.string("admin.members.operationFailed") }
        if !password.isEmpty && !(8...20).contains(password.count) {
            return AdminLocalization.string("admin.members.passwordLength")
        }
        if !confirmation.isEmpty && password != confirmation {
            return AdminLocalization.string("admin.members.passwordMismatch")
        }
        return nil
    }

    private func updateDirtyState() {
        interactionState.isDirty = AdminModalInteractionState.passwordIsDirty(
            password: password,
            confirmation: confirmation
        )
        saveFailed = false
    }

    private func save() async {
        interactionState.isSaving = true
        do {
            try await model.changePassword(memberID: member.id, newPassword: password)
            interactionState.isSaving = false
            onSuccess()
        } catch {
            interactionState.isSaving = false
            saveFailed = true
        }
    }
}

struct AdminPaginationFooter: View {
    let page: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Label(AdminLocalization.string("admin.common.previous"), systemImage: "chevron.left")
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .disabled(page <= 0)
            Spacer()
            Text(AdminLocalization.format("admin.common.page", page + 1, max(totalPages, 1)))
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textSecondary)
            Spacer()
            Button(action: onNext) {
                Label(AdminLocalization.string("admin.common.next"), systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .disabled(page >= totalPages - 1)
        }
    }
}
