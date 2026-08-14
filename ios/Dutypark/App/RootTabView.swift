import SwiftUI

@MainActor
enum RootAuthenticatedStartupAction {
    static func perform(
        startPolling: () -> Void,
        refreshNotifications: () async -> Void,
        activatePush: () async -> Void,
        consumePendingPush: () async -> Void,
        consumePendingDestination: () -> Void
    ) async {
        startPolling()
        await refreshNotifications()
        await activatePush()
        await consumePendingPush()
        consumePendingDestination()
    }
}

@MainActor
enum RootSceneLifecycleAction {
    static func perform(
        isActive: Bool,
        setNotificationForeground: (Bool) async -> Void,
        refreshHome: () -> Void,
        refreshConsent: () -> Void,
        resumePush: () async -> Void,
        consumePendingPush: () async -> Void
    ) async {
        await setNotificationForeground(isActive)
        guard isActive else { return }
        refreshHome()
        refreshConsent()
        await resumePush()
        await consumePendingPush()
    }
}

@MainActor
enum RootPendingPushAction {
    static func perform(
        consume: () -> NotificationID?,
        open: (NotificationID) async throws -> Bool,
        showFallback: () -> Void
    ) async {
        guard let notificationID = consume() else { return }
        do {
            guard try await open(notificationID) else {
                showFallback()
                return
            }
        } catch {
            showFallback()
        }
    }
}

@MainActor
enum RootPendingDestinationAction {
    static func perform(
        consume: () -> URL?,
        open: (URL) -> Bool,
        showUnsupported: () -> Void
    ) {
        guard let destination = consume() else { return }
        guard !open(destination), RootNavigationPolicy.isFirstPartyWebURL(destination) else {
            return
        }
        showUnsupported()
    }
}

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var session: SessionStore
    @StateObject private var notifications = NotificationStore()
    @StateObject private var pushCenter = NotificationPushCenter.shared
    @State private var selectedTab = AppTab.home
    @State private var homeRefreshID = 0
    @State private var homePath: [HomeDestination] = []
    @State private var calendarTarget = CalendarTarget()
    @State private var todoTarget: TodoID?
    @State private var settingsDestination: SettingsDestination?
    @State private var showsNotifications = false
    @State private var showsNotificationCenter = false
    @State private var showsUnsupportedLink = false
    @State private var showsLogoutConfirmation = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: tabSelection) {
                homeTab
                primaryTab(.calendar) {
                    CalendarView(
                        memberID: calendarTarget.memberID,
                        date: calendarTarget.date,
                        scheduleID: calendarTarget.scheduleID
                    )
                        .id(calendarTarget)
                }
                primaryTab(.todo, showsNavigationBar: true) {
                    TodoView(initialTodoID: todoTarget) {
                        todoTarget = nil
                    }
                }
                primaryTab(.team) { TeamView(onOpenCalendar: openMemberCalendar) }
                primaryTab(.settings) {
                    SettingsView(destination: $settingsDestination) {
                        homeRefreshID &+= 1
                    }
                }
            }
            .accessibilityIdentifier("primary.tabbar")

            if showsNotifications {
                notificationDropdownLayer
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(.easeOut(duration: 0.2), value: showsNotifications)
        .sheet(isPresented: $showsNotificationCenter) {
            NavigationStack {
                NotificationCenterView(store: notifications, onOpen: openNotificationRoute)
            }
        }
        .task {
            await RootAuthenticatedStartupAction.perform(
                startPolling: { notifications.startPolling() },
                refreshNotifications: { await notifications.refresh() },
                activatePush: {
                    await APNsRegistrationManager.shared.activateForAuthenticatedSession()
                },
                consumePendingPush: { await openPendingPushIfNeeded() },
                consumePendingDestination: openPendingDestinationIfNeeded
            )
        }
        .onDisappear {
            notifications.stopPolling()
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                await RootSceneLifecycleAction.perform(
                    isActive: phase == .active,
                    setNotificationForeground: {
                        await notifications.setForeground($0)
                    },
                    refreshHome: { homeRefreshID &+= 1 },
                    refreshConsent: refreshConsentIfNeeded,
                    resumePush: {
                        await APNsRegistrationManager.shared.resumeRegistration()
                    },
                    consumePendingPush: { await openPendingPushIfNeeded() }
                )
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .home {
                homeRefreshID &+= 1
            }
        }
        .onChange(of: showsNotifications) { _, isPresented in
            guard isPresented else { return }
            Task { await notifications.refresh() }
        }
        .onChange(of: pushCenter.pendingNotificationID) { _, notificationID in
            guard notificationID != nil else { return }
            Task { await openPendingPushIfNeeded() }
        }
        .onOpenURL { url in
            if !open(url), url.scheme?.lowercased() == "https",
               url.host?.lowercased() == "dutypark.o-r.kr" {
                showsUnsupportedLink = true
            }
        }
        .alert("link.unsupported.title", isPresented: $showsUnsupportedLink) {
            Button("link.unsupported.ok", role: .cancel) {}
        } message: {
            Text("link.unsupported.message")
        }
        .confirmationDialog(
            SettingsLocalization.string("settings.logout.confirmTitle"),
            isPresented: $showsLogoutConfirmation
        ) {
            Button(SettingsLocalization.string("settings.logout"), role: .destructive) {
                Task {
                    await session.logout()
                }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        } message: {
            SettingsLocalization.text("settings.logout.confirmMessage")
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            if case .authenticated(let member) = session.state, member.isImpersonating {
                ImpersonationBanner()
            }
        }
        .tint(DPColor.accent)
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            HomeView(refreshID: homeRefreshID, onRoute: openHomeRoute)
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("screen.home")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        DPBrandMark(action: openHome)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        HStack(spacing: 0) {
                        notificationBell
                        Button {
                            homePath.append(.menu)
                        } label: {
                            Image(systemName: "line.3.horizontal")
                                .font(.system(size: 18, weight: .semibold))
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                                .contentShape(Rectangle())
                        }
                        .accessibilityLabel(Text("home.menu", tableName: "Home"))
                        .accessibilityIdentifier("home.menu")
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .friends:
                        SocialView(
                            onMutation: socialDidMutate,
                            onOpenCalendar: openMemberCalendar
                        )
                    case .menu:
                        AppMenuView(
                            onOpenCalendar: openMyCalendar,
                            onOpenTeam: { selectedTab = .team },
                            onOpenFriends: openFriends,
                            onOpenTodo: { selectedTab = .todo },
                            onOpenNotifications: {
                                homePath.removeAll()
                                showsNotificationCenter = true
                            },
                            onOpenGuide: openGuide,
                            onOpenSettings: openSettings,
                            isAdmin: authenticatedMember?.isAdmin == true,
                            onOpenAdmin: { homePath.append(.admin) },
                            onLogout: { showsLogoutConfirmation = true }
                        )
                    case .admin:
                        if authenticatedMember?.isAdmin == true {
                            AdminRootView(onOpenCalendar: openMemberCalendar)
                        } else {
                            ContentUnavailableView(
                                AdminLocalization.string("admin.access.title"),
                                systemImage: "lock.shield"
                            )
                        }
                    }
                }
        }
        .primaryTabItem(.home)
    }

    private func primaryTab<Content: View>(
        _ tab: AppTab,
        showsNavigationBar: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationTitle("")
                .toolbar(showsNavigationBar ? .visible : .hidden, for: .navigationBar)
                .accessibilityIdentifier("screen.\(tab.rawValue)")
        }
        .primaryTabItem(tab)
    }

    private var notificationBell: some View {
        NotificationBellButton(store: notifications, isPresented: $showsNotifications)
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { destination in
                if RootNavigationPolicy.resetsHomePath(for: destination) {
                    homePath.removeAll()
                }
                if RootNavigationPolicy.resetsCalendarTarget(
                    for: destination,
                    origin: .tabBar
                ) {
                    calendarTarget = CalendarTarget(memberID: authenticatedMemberID)
                }
                selectedTab = destination
            }
        )
    }

    private func openHome() {
        homePath.removeAll()
        selectedTab = .home
    }

    private func openMyCalendar() {
        calendarTarget = CalendarTarget(memberID: authenticatedMemberID)
        selectedTab = .calendar
    }

    private func openFriends() {
        homePath = [.friends]
        selectedTab = .home
    }

    private func openGuide() {
        settingsDestination = .guide
        selectedTab = .settings
    }

    private func openSettings() {
        settingsDestination = nil
        selectedTab = .settings
    }

    private var notificationDropdownLayer: some View {
        ZStack(alignment: .topTrailing) {
            DPColor.textOnLight.opacity(0.30)
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture { showsNotifications = false }
                .accessibilityLabel(String(localized: "notifications.common.close", table: "Notifications"))
                .accessibilityAddTraits(.isButton)
                .accessibilityAction { showsNotifications = false }

            NotificationDropdown(
                store: notifications,
                onOpen: openDropdownNotification,
                onViewAll: {
                    showsNotifications = false
                    showsNotificationCenter = true
                }
            )
            .frame(maxWidth: 384)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.top, DPSpacing.extraSmall)
        }
        .accessibilityAction(.escape) { showsNotifications = false }
        .zIndex(10)
    }

    private func openDropdownNotification(_ notification: NotificationDTO) async {
        guard let route = await notifications.open(notification) else { return }
        if await openNotificationRoute(route) {
            showsNotifications = false
        }
    }

    private func openHomeRoute(_ route: HomeRoute) {
        switch route {
        case .memberCalendar(let memberID):
            openMemberCalendar(memberID)
        case .friends:
            homePath.append(.friends)
        }
    }

    private func openMemberCalendar(_ memberID: MemberID) {
        calendarTarget = CalendarTarget(memberID: memberID)
        selectedTab = .calendar
    }

    private func socialDidMutate(_ affectsReceivedRequestCount: Bool) async {
        homeRefreshID &+= 1
        if affectsReceivedRequestCount {
            await notifications.refresh()
        }
    }

    private func openNotificationRoute(_ route: NotificationRoute) async -> Bool {
        switch route {
        case .friends:
            selectedTab = .home
            homePath = [.friends]
            return true
        case .schedule(let scheduleID), .taggedSchedule(let scheduleID):
            return await openScheduleCalendar(scheduleID, route: route)
        case .member(let memberID):
            openMemberCalendar(memberID)
            return true
        case .todo(let todoID):
            todoTarget = todoID
            selectedTab = .todo
            return true
        }
    }

    private var authenticatedMemberID: MemberID? {
        authenticatedMember?.id
    }

    private var authenticatedMember: LoginMember? {
        guard case .authenticated(let member) = session.state else { return nil }
        return member
    }

    private func openScheduleCalendar(
        _ scheduleID: ScheduleID,
        route: NotificationRoute
    ) async -> Bool {
        guard let schedule: ScheduleBasicInfoDTO = try? await APIClient.shared.request(
            "schedules/\(scheduleID.uuidString)"
        ) else { return false }
        calendarTarget = CalendarTarget(
            memberID: RootNavigationPolicy.scheduleMemberID(
                for: route,
                authenticatedMemberID: authenticatedMemberID,
                scheduleOwnerID: schedule.memberId
            ),
            date: DateOnly(rawValue: String(schedule.startDateTime.rawValue.prefix(10))),
            scheduleID: scheduleID
        )
        selectedTab = .calendar
        return true
    }

    private func refreshConsentIfNeeded() {
        guard let memberID = authenticatedMemberID else { return }
        Task {
            await AIScheduleParsingConsentStore.shared.refreshIfStale(
                for: memberID,
                minimumInterval: 30
            )
        }
    }

    private func openPendingPushIfNeeded() async {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            return
        }
#endif
        await RootPendingPushAction.perform(
            consume: pushCenter.consumePendingNotificationID,
            open: { notificationID in
                guard let route = try await notifications.open(id: notificationID) else {
                    return false
                }
                return await openNotificationRoute(route)
            },
            showFallback: { showsNotifications = true }
        )
    }

    private func openPendingDestinationIfNeeded() {
        RootPendingDestinationAction.perform(
            consume: session.consumePendingDestination,
            open: open,
            showUnsupported: { showsUnsupportedLink = true }
        )
    }

    @discardableResult
    private func open(_ url: URL) -> Bool {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == "dutypark.o-r.kr"
        else { return false }

        let components = url.pathComponents.filter { $0 != "/" }
        if components.count == 2,
           components[0] == "duty",
           let memberID = MemberID(components[1]),
           memberID > 0 {
            openMemberCalendar(memberID)
            return true
        }
        if let destination = SettingsDeepLink.destination(from: url) {
            settingsDestination = destination
            selectedTab = .settings
            return true
        }

        switch components.first {
        case "todo":
            selectedTab = .todo
        case "team":
            selectedTab = .team
        case "member":
            settingsDestination = nil
            selectedTab = .settings
        case "friends":
            selectedTab = .home
            homePath = [.friends]
        case "notifications":
            showsNotifications = true
        case nil:
            selectedTab = .home
        default:
            return false
        }
        return true
    }
}

nonisolated enum RootNavigationPolicy {
    static func isFirstPartyWebURL(_ url: URL) -> Bool {
        url.scheme?.lowercased() == "https"
            && url.host?.lowercased() == "dutypark.o-r.kr"
    }

    static func resetsHomePath(for destination: AppTab) -> Bool {
        destination == .home
    }

    static func resetsCalendarTarget(
        for destination: AppTab,
        origin: RootTabSelectionOrigin
    ) -> Bool {
        destination == .calendar && origin == .tabBar
    }

    static func scheduleMemberID(
        for route: NotificationRoute,
        authenticatedMemberID: MemberID?,
        scheduleOwnerID: MemberID
    ) -> MemberID? {
        switch route {
        case .schedule:
            scheduleOwnerID
        case .taggedSchedule:
            authenticatedMemberID ?? scheduleOwnerID
        default:
            nil
        }
    }
}

nonisolated enum RootTabSelectionOrigin: Equatable, Sendable {
    case tabBar
    case explicitRoute
}

private enum HomeDestination: Hashable {
    case friends
    case menu
    case admin
}

private struct AppMenuView: View {
    let onOpenCalendar: () -> Void
    let onOpenTeam: () -> Void
    let onOpenFriends: () -> Void
    let onOpenTodo: () -> Void
    let onOpenNotifications: () -> Void
    let onOpenGuide: () -> Void
    let onOpenSettings: () -> Void
    let isAdmin: Bool
    let onOpenAdmin: () -> Void
    let onLogout: () -> Void

    private let columns = [
        GridItem(.flexible(), spacing: DPSpacing.small),
        GridItem(.flexible(), spacing: DPSpacing.small)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: DPSpacing.medium) {
                LazyVGrid(columns: columns, spacing: DPSpacing.small) {
                    AppMenuTile(
                        title: String(localized: AppTab.calendar.tabTitle),
                        systemImage: AppTab.calendar.systemImage,
                        color: DPColor.accent,
                        action: onOpenCalendar
                    )
                    AppMenuTile(
                        title: String(localized: AppTab.team.tabTitle),
                        systemImage: AppTab.team.systemImage,
                        color: DPColor.success,
                        action: onOpenTeam
                    )
                    AppMenuTile(
                        title: String(localized: "home.friends", table: "Home"),
                        systemImage: "person.2",
                        color: DPColor.warning,
                        action: onOpenFriends
                    )
                    AppMenuTile(
                        title: String(localized: AppTab.todo.tabTitle),
                        systemImage: AppTab.todo.systemImage,
                        color: DPColor.danger,
                        action: onOpenTodo
                    )
                    AppMenuTile(
                        title: String(localized: "notifications.title", table: "Notifications"),
                        systemImage: "bell",
                        color: DPColor.accentHover,
                        action: onOpenNotifications
                    )
                    AppMenuTile(
                        title: String(localized: AppTab.settings.tabTitle),
                        systemImage: AppTab.settings.systemImage,
                        color: DPColor.textSecondary,
                        action: onOpenSettings
                    )
                }

                if isAdmin {
                    VStack(alignment: .leading, spacing: DPSpacing.small) {
                        Text(AdminLocalization.string("admin.menu.section"))
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                            .padding(.horizontal, DPSpacing.extraSmall)

                        AppMenuRow(
                            title: AdminLocalization.string("admin.menu.title"),
                            systemImage: "lock.shield",
                            action: onOpenAdmin
                        )
                    }
                    .padding(DPSpacing.small)
                    .background(DPColor.backgroundCard)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                    }
                    .accessibilityIdentifier("menu.admin.section")
                }

                VStack(spacing: 0) {
                    AppMenuRow(
                        title: SettingsLocalization.string("settings.guide"),
                        systemImage: "book",
                        action: onOpenGuide
                    )
                    Divider().overlay(DPColor.borderPrimary)
                    AppMenuRow(
                        title: SettingsLocalization.string("settings.logout"),
                        systemImage: "rectangle.portrait.and.arrow.right",
                        role: .destructive,
                        action: onLogout
                    )
                }
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                .overlay {
                    RoundedRectangle(cornerRadius: DPRadius.large)
                        .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                }
            }
            .padding(DPSpacing.medium)
        }
        .background(DPColor.backgroundPrimary)
        .navigationTitle(Text("home.menu", tableName: "Home"))
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("screen.menu")
    }
}

private struct AppMenuTile: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                Image(systemName: systemImage)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(color)
                    .frame(width: 44, height: 44)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))

                HStack(spacing: DPSpacing.extraSmall) {
                    Text(title)
                        .font(DPFont.bold(size: 16, relativeTo: .body))
                        .foregroundStyle(DPColor.textPrimary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(DPColor.textMuted)
                }
            }
            .padding(DPSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .leading)
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.large)
                    .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct AppMenuRow: View {
    let title: String
    let systemImage: String
    var role: ButtonRole?
    let action: () -> Void

    var body: some View {
        Button(role: role, action: action) {
            HStack(spacing: DPSpacing.compact) {
                Image(systemName: systemImage)
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: 32)
                Text(title)
                    .font(DPTypography.body)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
            }
            .foregroundStyle(role == .destructive ? DPColor.danger : DPColor.textPrimary)
            .padding(.horizontal, DPSpacing.medium)
            .frame(maxWidth: .infinity, minHeight: 56)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

private struct CalendarTarget: Hashable {
    var memberID: MemberID?
    var date: DateOnly?
    var scheduleID: ScheduleID?
}

private struct ImpersonationBanner: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.clock")
                VStack(alignment: .leading, spacing: 1) {
                    Text("auth.impersonation.active")
                        .font(.caption.weight(.semibold))
                    if let remaining = session.impersonationRemainingTime(at: context.date) {
                        Text(
                            String(
                                format: String(localized: "auth.impersonation.remaining"),
                                locale: .current,
                                Self.duration(remaining)
                            )
                        )
                        .font(.caption2.monospacedDigit())
                    }
                }
                Spacer(minLength: 4)
                Button(String(localized: "settings.managed.restore", table: "Settings")) {
                    Task { await session.restoreOriginalAccount() }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            .background(.orange.opacity(0.18))
            .accessibilityIdentifier("impersonation.banner")
        }
    }

    private static func duration(_ interval: TimeInterval) -> String {
        let totalSeconds = max(0, Int(interval.rounded(.down)))
        return String(format: "%d:%02d", totalSeconds / 60, totalSeconds % 60)
    }
}

private struct NotificationDropdown: View {
    @ObservedObject var store: NotificationStore
    let onOpen: (NotificationDTO) async -> Void
    let onViewAll: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(String(localized: "notifications.title", table: "Notifications"))
                .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DPSpacing.medium)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundTertiary)

            Divider().overlay(DPColor.borderPrimary)

            Group {
                if store.isLoading && store.notifications.isEmpty {
                    ProgressView(String(localized: "notifications.common.loading", table: "Notifications"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else if store.notifications.isEmpty {
                    Text(String(localized: "notifications.common.empty", table: "Notifications"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(store.notifications.prefix(10)), id: \.id) { notification in
                                NotificationDropdownRow(notification: notification) {
                                    Task { await onOpen(notification) }
                                }

                                if notification.id != store.notifications.prefix(10).last?.id {
                                    Divider().overlay(DPColor.borderPrimary)
                                }
                            }
                        }
                    }
                    .frame(maxHeight: 320)
                }
            }
            .background(DPColor.backgroundCard)

            Divider().overlay(DPColor.borderPrimary)

            Button(action: onViewAll) {
                HStack(spacing: DPSpacing.extraSmall) {
                    Text(String(localized: "notifications.dropdown.viewAll", table: "Notifications"))
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .semibold))
                }
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .background(DPColor.backgroundTertiary)
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderSecondary, lineWidth: DPChrome.borderWidth)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
        .accessibilityIdentifier("notifications.dropdown")
    }
}

private struct NotificationDropdownRow: View {
    let notification: NotificationDTO
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DPSpacing.compact) {
                ZStack(alignment: .topTrailing) {
                    Circle()
                        .fill(DPColor.backgroundTertiary)
                        .frame(width: 36, height: 36)
                        .overlay {
                            Image(systemName: "person.fill")
                                .font(.system(size: 15))
                                .foregroundStyle(DPColor.textMuted)
                        }

                    if !notification.isRead {
                        Circle()
                            .fill(DPColor.accent)
                            .frame(width: 10, height: 10)
                            .overlay(Circle().stroke(DPColor.backgroundCard, lineWidth: 2))
                            .offset(x: 2, y: -2)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(NotificationPresentation.message(for: notification))
                        .font(notification.isRead ? DPTypography.label : DPFont.bold(size: 14, relativeTo: .subheadline))
                        .foregroundStyle(notification.isRead ? DPColor.textSecondary : DPColor.textPrimary)
                        .lineLimit(1)

                    if let date = NotificationPresentation.date(from: notification.createdAt) {
                        Text(date, style: .relative)
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(height: 36)
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.compact)
            .frame(minHeight: 60)
            .background(notification.isRead ? DPColor.backgroundCard : DPColor.backgroundTertiary)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityIdentifier("notifications.dropdown.row.\(notification.id.uuidString)")
    }
}

private extension View {
    func primaryTabItem(_ tab: AppTab) -> some View {
        tabItem {
            Label {
                Text(tab.tabTitle)
            } icon: {
                Image(systemName: tab.systemImage)
                    .accessibilityIdentifier(tab.accessibilityIdentifier)
            }
        }
        .tag(tab)
    }
}

private struct RootTabViewPreview: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
