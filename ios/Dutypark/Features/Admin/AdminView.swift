import SwiftUI

struct AdminRootView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.openURL) private var openURL
    @StateObject private var memberModel: AdminMemberListViewModel
    @State private var searchText = ""
    @State private var searchTask: Task<Void, Never>?
    @State private var destination: AdminRootDestination?
    @State private var sessionConfirmation: AdminSessionRevokeConfirmation?
    @State private var isRevokingSession = false
    @State private var operationMessage: String?
    @FocusState private var isSearchFocused: Bool
    /// The web keeps a separate initial-load flag so a search that empties the list never replaces
    /// the whole page — and never tears the focused search field out of the hierarchy.
    @State private var hasCompletedInitialLoad = false
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
                dashboard
            } else {
                ContentUnavailableView(
                    AdminLocalization.string("admin.access.title"),
                    systemImage: "lock.shield",
                    description: Text(AdminLocalization.string("admin.access.message"))
                )
            }
        }
        .navigationTitle(AdminLocalization.string("admin.menu.title"))
        // Inline like every other pushed screen: a large title spent a whole row on a
        // word the navigation bar above it was already free to carry.
        .navigationBarTitleDisplayMode(.inline)
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

    private var dashboard: some View {
        ScrollView {
            VStack(spacing: 0) {
                if !hasCompletedInitialLoad && memberModel.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 80)
                } else {
                    navigationTiles
                    statsBand
                    memberCard
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.large)
        }
        .background(DPColor.backgroundSecondary)
        .refreshable { await memberModel.load() }
        .dpKeyboardDismissToolbar()
        .onChange(of: searchText) { _, newValue in
            searchTask?.cancel()
            let keyword = AdminMemberSearchPolicy.normalized(newValue)
            searchTask = Task {
                try? await Task.sleep(for: AdminMemberSearchPolicy.debounce)
                guard !Task.isCancelled else { return }
                await memberModel.search(keyword)
            }
        }
        .task {
            await memberModel.load()
            hasCompletedInitialLoad = true
        }
        .onDisappear { searchTask?.cancel() }
        .fullScreenCover(item: $sessionConfirmation) { confirmation in
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { sessionConfirmation = nil },
                canDismiss: !isRevokingSession,
                onDismissRequest: { _ in
                    guard !isRevokingSession else { return }
                    sessionConfirmation = nil
                    DPHapticCenter.shared.emit(.routine)
                },
                dismissHaptic: nil
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

    private var navigationTiles: some View {
        LazyVGrid(columns: dashboardColumns, spacing: DPSpacing.small) {
            AdminTopTile(
                title: AdminLocalization.string("admin.nav.members"),
                systemImage: "person.3.fill",
                isSelected: true
            )
            .accessibilityIdentifier("admin.tile.members")

            Button {
                DPHapticCenter.shared.emit(.routine)
                destination = .teams
            } label: {
                AdminTopTile(
                    title: AdminLocalization.string("admin.nav.teams"),
                    systemImage: "building.2.fill"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("admin.tile.teams")

            Button {
                DPHapticCenter.shared.emit(.routine)
                destination = .development
            } label: {
                AdminTopTile(
                    title: AdminLocalization.string("admin.nav.development"),
                    systemImage: "chevron.left.forwardslash.chevron.right"
                )
            }
            .buttonStyle(.plain)
            .accessibilityIdentifier("admin.tile.development")

            Button {
                DPHapticCenter.shared.emit(.routine)
                openURL(AdminWebDestination.apiDocumentationURL())
            } label: {
                AdminTopTile(
                    title: AdminLocalization.string("admin.nav.apiDocumentation"),
                    systemImage: "doc.text.fill"
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(AdminLocalization.string("admin.nav.apiDocumentation"))
            .accessibilityHint(
                AdminLocalization.string("admin.nav.apiDocumentation.externalHint")
            )
            .accessibilityIdentifier("admin.tile.apiDocumentation")
        }
        .padding(.bottom, DPSpacing.medium)
    }

    private var statsBand: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.tiles.enumerated()), id: \.offset) { index, tile in
                if index > 0 {
                    DPColor.borderPrimary.opacity(0.78)
                        .frame(width: 1)
                }
                AdminStatTile(
                    kicker: AdminLocalization.string(tile.key.label),
                    value: tile.value,
                    note: AdminLocalization.string(tile.key.note)
                )
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .background(AdminStatsBandBackground())
        .clipShape(RoundedRectangle(cornerRadius: AdminStatsBandPresentation.cornerRadius))
        .overlay {
            RoundedRectangle(cornerRadius: AdminStatsBandPresentation.cornerRadius)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .padding(.bottom, DPSpacing.medium)
        .accessibilityElement(children: .contain)
        .accessibilityLabel(AdminLocalization.string("admin.dashboard.statsAriaLabel"))
    }

    private var memberCard: some View {
        VStack(spacing: 0) {
            memberCardHeader
            memberCardBody
            if memberModel.totalPages > 1 {
                DPColor.borderPrimary.frame(height: 1)
                AdminMemberPaginationFooter(
                    presentation: AdminMemberPaginationPresentation(
                        page: memberModel.page,
                        pageSize: AdminMemberListViewModel.pageSize,
                        totalElements: memberModel.totalElements
                    ),
                    page: memberModel.page,
                    totalPages: memberModel.totalPages,
                    onPrevious: { Task { await memberModel.movePage(by: -1) } },
                    onNext: { Task { await memberModel.movePage(by: 1) } }
                )
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.large)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
    }

    private var memberCardHeader: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            Text(AdminLocalization.string("admin.dashboard.title"))
                .font(DPFont.bold(size: 18, relativeTo: .headline))
                .foregroundStyle(DPColor.textPrimary)

            HStack(spacing: 0) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: DPSize.iconSmall))
                    .foregroundStyle(DPColor.textMuted)
                    .padding(.leading, DPSpacing.compact)
                TextField(
                    "",
                    text: $searchText,
                    prompt: Text(AdminLocalization.string("admin.dashboard.searchPlaceholder"))
                        .foregroundColor(DPColor.textMuted)
                )
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textPrimary)
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .submitLabel(.search)
                .padding(.leading, DPSpacing.small)
                .padding(.trailing, DPSpacing.medium)
                .padding(.vertical, DPSpacing.small)
                .accessibilityIdentifier("admin.members.search")
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundInput)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(
                        isSearchFocused ? DPColor.textPrimary : DPColor.borderInput,
                        lineWidth: isSearchFocused ? DPChrome.focusRingWidth : DPChrome.borderWidth
                    )
            }
        }
        .padding(DPSpacing.medium)
        .overlay(alignment: .bottom) {
            DPColor.borderPrimary.frame(height: 1)
        }
    }

    @ViewBuilder
    private var memberCardBody: some View {
        if memberModel.isLoading {
            ProgressView()
                .frame(maxWidth: .infinity)
                .padding(.vertical, 48)
        } else if memberModel.loadFailed && memberModel.members.isEmpty {
            Button {
                DPHapticCenter.shared.emit(.routine)
                Task { await memberModel.load() }
            } label: {
                Label(
                    AdminLocalization.string("admin.members.loadFailed"),
                    systemImage: "arrow.clockwise"
                )
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.accent)
                .frame(maxWidth: .infinity)
                .padding(DPSpacing.extraLarge)
            }
            .buttonStyle(.plain)
        } else if memberModel.members.isEmpty {
            Text(AdminLocalization.string("admin.dashboard.empty"))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textMuted)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(DPSpacing.extraLarge)
                .accessibilityIdentifier("admin.members.empty")
        } else {
            ForEach(memberModel.members) { member in
                AdminMemberRow(member: member) { token in
                    sessionConfirmation = AdminSessionRevokeConfirmation(token: token)
                } detail: {
                    AdminMemberDetailView(
                        member: member,
                        model: memberModel,
                        onOpenCalendar: onOpenCalendar
                    )
                }
            }
        }
    }

    private var isAdmin: Bool {
        guard case .authenticated(let member) = session.state else { return false }
        return member.isAdmin
    }

    private var dashboardColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(), spacing: DPSpacing.small),
            count: AdminTopTilePresentation.columnCount
        )
    }

    private var stats: AdminDashboardStatsPresentation {
        AdminDashboardStatsPresentation(
            totalMembers: memberModel.totalElements,
            loadedMembers: memberModel.members,
            sessions: memberModel.sessions,
            today: AdminDashboardStatsPresentation.todayString()
        )
    }

    private func revokeSession(
        _ confirmation: AdminSessionRevokeConfirmation,
        dismiss: @escaping () -> Void
    ) {
        guard !isRevokingSession else { return }
        isRevokingSession = true

        Task {
            do {
                try await memberModel.revokeSession(id: confirmation.token.id)
                operationMessage = AdminLocalization.string("admin.members.sessionRevoked")
            } catch {
                operationMessage = AdminLocalization.string("admin.members.operationFailed")
            }
            isRevokingSession = false
            dismiss()
        }
    }
}

private struct AdminTopTile: View {
    let title: String
    let systemImage: String
    var isSelected = false

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: 18.4, weight: .semibold))
                .foregroundStyle(
                    isSelected ? AdminTopTilePresentation.selectedForeground : DPColor.textSecondary
                )
                .padding(.bottom, DPSpacing.small)
            Text(title)
                .font(DPFont.bold(size: 11.5, relativeTo: .caption2))
                .foregroundStyle(
                    isSelected ? AdminTopTilePresentation.selectedForeground : DPColor.textPrimary
                )
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.8)
        }
        .padding(.vertical, DPSpacing.compact)
        .padding(.horizontal, 6.4)
        .frame(maxWidth: .infinity, minHeight: 85)
        .background(
            isSelected ? AdminTopTilePresentation.selectedBackground : DPColor.backgroundCard,
            in: RoundedRectangle(cornerRadius: DPRadius.extraLarge)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.extraLarge)
                .stroke(
                    isSelected ? Color.clear : DPColor.borderPrimary,
                    lineWidth: DPChrome.borderWidth
                )
        }
    }
}

private struct AdminStatTile: View {
    let kicker: String
    let value: Int
    let note: String

    var body: some View {
        VStack(spacing: 0) {
            Text(kicker)
                .font(DPFont.bold(size: 10.9, relativeTo: .caption2))
                .foregroundStyle(DPColor.textMuted)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
            Text(value.formatted())
                .font(DPFont.bold(size: 24.8, relativeTo: .title2))
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(.top, 3.2)
            Text(note)
                .font(DPFont.light(size: 10.9, relativeTo: .caption2))
                .foregroundStyle(DPColor.textSecondary)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .padding(.top, 2.6)
        }
        .multilineTextAlignment(.center)
        .padding(.top, 10.9)
        .padding(.horizontal, 4.8)
        .padding(.bottom, 9.9)
        .frame(maxWidth: .infinity, minHeight: 82.4)
    }
}

nonisolated enum AdminStatsBandPresentation {
    static let cornerRadius: CGFloat = 18.4
}

/// The web paints the band with `color-mix`, which SwiftUI has no direct equivalent for, so the
/// same result is layered as translucent secondary/tertiary tints over the card color.
private struct AdminStatsBandBackground: View {
    var body: some View {
        DPColor.backgroundCard
            .overlay {
                LinearGradient(
                    colors: [
                        DPColor.backgroundSecondary.opacity(0.08),
                        DPColor.backgroundTertiary.opacity(0.20),
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
    }
}

private struct AdminMemberRow<Detail: View>: View {
    let member: AdminMemberDTO
    let onRevoke: (SettingsRefreshToken) -> Void
    @ViewBuilder let detail: Detail

    init(
        member: AdminMemberDTO,
        onRevoke: @escaping (SettingsRefreshToken) -> Void,
        @ViewBuilder detail: () -> Detail
    ) {
        self.member = member
        self.onRevoke = onRevoke
        self.detail = detail()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            NavigationLink {
                detail
            } label: {
                header
            }
            .buttonStyle(.plain)
            .simultaneousGesture(TapGesture().onEnded {
                DPHapticCenter.shared.emit(.routine)
            })
            // The identifier stays on the link rather than the row: SwiftUI pushes a container
            // identifier down onto its children, which would hide the inline session controls.
            .accessibilityIdentifier("admin.member.\(member.id)")
            .padding(.bottom, DPSpacing.compact)

            if !member.tokens.isEmpty {
                AdminMemberSessionList(
                    memberID: member.id,
                    tokens: member.tokens,
                    onRevoke: onRevoke
                )
                .padding(.top, DPSpacing.small)
            }
        }
        .padding(DPSpacing.medium)
        .overlay(alignment: .bottom) {
            DPColor.borderSecondary.frame(height: 1)
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            AdminMemberAvatar(
                memberID: member.id,
                name: member.name,
                version: member.profilePhotoVersion,
                size: 36
            )
            VStack(alignment: .leading, spacing: 0) {
                Text(member.name)
                    .font(DPFont.bold(size: 16, relativeTo: .body))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Text(AdminMemberSessionCountPresentation.text(count: member.tokens.count))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
            }
            Spacer(minLength: DPSpacing.compact)
            VStack(alignment: .trailing, spacing: DPSpacing.extraSmall) {
                Text(
                    member.teamName
                        ?? AdminLocalization.string("admin.dashboard.memberRow.noTeam")
                )
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .lineLimit(1)
                Image(systemName: "chevron.right")
                    .font(.system(size: DPSize.iconSmall))
                    .foregroundStyle(DPColor.textMuted)
            }
        }
        .contentShape(Rectangle())
    }
}

private struct AdminMemberPaginationFooter: View {
    let presentation: AdminMemberPaginationPresentation
    let page: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack(spacing: 0) {
            Text(presentation.text)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: DPSpacing.small)
            HStack(spacing: DPSpacing.small) {
                pageButton(
                    systemImage: "chevron.left",
                    label: AdminLocalization.string("admin.common.previous"),
                    isDisabled: page <= 0,
                    action: onPrevious
                )
                Text("\(page + 1) / \(max(totalPages, 1))")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textPrimary)
                    .padding(.horizontal, DPSpacing.small)
                pageButton(
                    systemImage: "chevron.right",
                    label: AdminLocalization.string("admin.common.next"),
                    isDisabled: page >= totalPages - 1,
                    action: onNext
                )
            }
        }
        .padding(DPSpacing.medium)
    }

    private func pageButton(
        systemImage: String,
        label: String,
        isDisabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isDisabled else { return }
            DPHapticCenter.shared.emit(.selection)
            action()
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: DPSize.iconSmall))
                .foregroundStyle(DPColor.textSecondary)
                .padding(DPSpacing.small)
                .background(
                    DPColor.backgroundTertiary,
                    in: RoundedRectangle(cornerRadius: DPRadius.standard)
                )
                // The web chip is smaller than the iOS minimum touch target, so only the hit area grows.
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? DPChrome.disabledOpacity : 1)
        .accessibilityLabel(label)
    }
}

private struct AdminMemberAvatar: View {
    let memberID: MemberID
    let name: String
    let version: Int64
    let size: CGFloat

    var body: some View {
        DPProfileAvatar(
            memberID: memberID,
            profilePhotoVersion: version,
            size: size
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(name)
        .accessibilityIdentifier("admin.member.avatar.\(memberID)")
    }
}

nonisolated enum AdminTopTilePresentation {
    /// The web tile row is always four-up, including at the mobile breakpoint.
    static let columnCount = 4
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

/// Each stats-band tile carries a kicker and a note, matching the web band.
nonisolated struct AdminDashboardStatKey: Equatable, Sendable {
    let label: String
    let note: String
}

nonisolated struct AdminDashboardStatTile: Equatable, Sendable {
    let key: AdminDashboardStatKey
    let value: Int
}

nonisolated struct AdminDashboardStatsPresentation: Equatable, Sendable {
    static let localizationKeys = [
        AdminDashboardStatKey(
            label: "admin.dashboard.stats.totalMembersLabel",
            note: "admin.dashboard.stats.totalMembersNote"
        ),
        AdminDashboardStatKey(
            label: "admin.dashboard.stats.totalTeamsLabel",
            note: "admin.dashboard.stats.totalTeamsNote"
        ),
        AdminDashboardStatKey(
            label: "admin.dashboard.stats.activeTokensLabel",
            note: "admin.dashboard.stats.activeTokensNote"
        ),
        AdminDashboardStatKey(
            label: "admin.dashboard.stats.todayLoginsLabel",
            note: "admin.dashboard.stats.todayLoginsNote"
        ),
    ]

    let totalMembers: Int64
    let teamCount: Int
    let activeSessionCount: Int
    let todayLoginCount: Int

    var values: [Int] {
        [Int(totalMembers), teamCount, activeSessionCount, todayLoginCount]
    }

    var tiles: [AdminDashboardStatTile] {
        zip(Self.localizationKeys, values).map { AdminDashboardStatTile(key: $0, value: $1) }
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
                canDismiss: !isRevokingSession,
                onDismissRequest: { _ in
                    guard !isRevokingSession else { return }
                    sessionConfirmation = nil
                    DPHapticCenter.shared.emit(.routine)
                },
                dismissHaptic: nil
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
            DPHapticCenter.shared.emit(.routine)
            showsPasswordSheet = false
        case .confirmDiscard:
            DPHapticCenter.shared.emit(.warning)
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

    private var client: AdminSessionClientPresentation {
        AdminSessionClientPresentation(token: token)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            HStack {
                Label(
                    token.userAgent?.device ?? AdminLocalization.string("admin.members.session.unknownDevice"),
                    systemImage: client.icon
                )
                .font(DPTypography.label)
                Spacer()
                Button(role: .destructive) {
                    onRevoke()
                } label: {
                    Image(systemName: "xmark.circle")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .accessibilityLabel(AdminLocalization.string("admin.members.revokeSession.action"))
                .accessibilityIdentifier("admin.member.session.revoke.\(token.id)")
            }
            Text(client.summary)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            Text(token.lastUsed ?? token.createdDate ?? token.validUntil)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
        }
        .padding(.vertical, DPSpacing.extraSmall)
    }
}

/// Native app sessions must not be listed under the browser name the app's user agent carries.
nonisolated struct AdminSessionClientPresentation: Equatable, Sendable {
    let icon: String
    let clientName: String
    let summary: String

    init(token: SettingsRefreshToken) {
        let isNativeApp = token.resolvedClientType == .iosApp
        icon = isNativeApp ? "apps.iphone" : "iphone"
        clientName = isNativeApp
            ? AdminLocalization.string("admin.members.session.iosApp")
            : (token.userAgent?.browser ?? "-")
        if let userAgent = token.userAgent {
            summary = "\(userAgent.os) · \(clientName)"
        } else {
            summary = isNativeApp ? clientName : "-"
        }
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
            AdminSessionClientPresentation(token: token).clientName,
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
        DPModalPanel(maximumPanelHeight: maximumHeight, scrollTarget: focusedField) {
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
            Button(action: requestDismiss) {
                Text(AdminLocalization.string("admin.common.close"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(interactionState.isSaving)

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
        .id(field)
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
