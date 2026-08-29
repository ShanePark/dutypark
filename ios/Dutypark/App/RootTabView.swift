import SwiftUI

@MainActor
enum RootAuthenticatedStartupAction {
    static func perform(
        isOffline: Bool = false,
        startPolling: () -> Void,
        refreshNotifications: () async -> Void,
        activatePush: () async -> Void,
        consumePendingPush: () async -> Void,
        consumePendingDestination: () -> Void
    ) async {
        guard !isOffline else { return }
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
        isNetworkAvailable: Bool = true,
        setNotificationForeground: (Bool) async -> Void,
        refreshHome: () -> Void,
        refreshConsent: () -> Void,
        resumePush: () async -> Void,
        consumePendingPush: () async -> Void
    ) async {
        // NotificationStore.refreshIfStale() is called when foreground becomes
        // true. Keep it false while the account is offline so scene activation
        // cannot create a request storm.
        await setNotificationForeground(isActive && isNetworkAvailable)
        guard isActive, isNetworkAvailable else { return }
        refreshHome()
        refreshConsent()
        await resumePush()
        await consumePendingPush()
    }
}

/// Coordinates the boundary between a cached session and the online-only root
/// features. The path monitor only permits an attempt; `revalidate` decides
/// whether the server session is actually alive.
@MainActor
enum RootConnectivityRecoveryAction {
    static func perform(
        networkStatus: OfflineNetworkStatus,
        availability: () -> SessionAvailability,
        revalidate: () async -> Void,
        startOnlineWork: () async -> Void
    ) async {
        guard networkStatus.isSatisfied else { return }
        if availability().isOffline {
            await revalidate()
        }
        guard !availability().isOffline else { return }
        await startOnlineWork()
    }
}

nonisolated enum RootOfflineDefaultTabPolicy {
    static func selectedTab(
        availability: SessionAvailability,
        current: AppTab,
        hasApplied: Bool
    ) -> AppTab {
        guard !hasApplied, availability.isOffline else { return current }
        return .calendar
    }
}

@MainActor
enum RootPendingPushAction {
    static func perform(
        isAuthenticated: Bool,
        isOnline: Bool,
        isActive: Bool,
        consume: () -> NotificationID?,
        showNotificationCenter: (NotificationID) -> Void
    ) async {
        guard isAuthenticated, isOnline, isActive else { return }
        guard let notificationID = consume() else { return }
        showNotificationCenter(notificationID)
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

struct RootNotificationDropdownReadPolicy {
    private var shouldMarkAllAsReadOnClose = false

    mutating func prepareForOpen() {
        shouldMarkAllAsReadOnClose = false
    }

    mutating func finishLoading(didLoad: Bool, isPresented: Bool, hasUnread: Bool) {
        shouldMarkAllAsReadOnClose = didLoad && isPresented && hasUnread
    }

    mutating func consumeClose() -> Bool {
        defer { shouldMarkAllAsReadOnClose = false }
        return shouldMarkAllAsReadOnClose
    }
}

struct RootNotificationDropdownSwipePolicy {
    static let minimumVerticalTranslation: CGFloat = 60

    static func followOffset(translation: CGSize) -> CGFloat {
        min(translation.height, 0)
    }

    static func shouldDismiss(translation: CGSize) -> Bool {
        translation.height < -minimumVerticalTranslation &&
            abs(translation.height) > abs(translation.width)
    }
}

struct RootHomeRefreshPolicy {
    static let minimumAutomaticInterval: TimeInterval = 5

    private var lastAutomaticRefreshAt: Date?

    init(initialRefreshAt: Date? = nil) {
        lastAutomaticRefreshAt = initialRefreshAt
    }

    mutating func shouldRefreshAutomatically(at now: Date = Date()) -> Bool {
        if let lastAutomaticRefreshAt,
           now.timeIntervalSince(lastAutomaticRefreshAt) < Self.minimumAutomaticInterval {
            return false
        }
        lastAutomaticRefreshAt = now
        return true
    }
}

struct RootTabView: View {
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var session: SessionStore
    @StateObject private var notifications = NotificationStore()
    @StateObject private var pushCenter = NotificationPushCenter.shared
    @StateObject private var offlineNetworkMonitor = OfflineNetworkMonitor.shared
    @StateObject private var offlineSyncCoordinator = OfflineSyncCoordinator.shared
    @State private var selectedTab = AppTab.home
    @State private var didApplyOfflineDefaultTab = false
    @State private var didStartOnlineWork = false
    @State private var isRecoveringConnectivity = false
    @State private var homeRefreshID = 0
    @State private var homeRefreshPolicy = RootHomeRefreshPolicy(initialRefreshAt: Date())
    @State private var homePath: [HomeDestination] = []
    @State private var calendarPath: [MemberCalendarRoute] = []
    @State private var calendarCurrentMonthRequestID = 0
    @State private var teamPath: [MemberCalendarRoute] = []
    @State private var morePath: [MoreDestination] = []
    @State private var todoTarget: TodoID?
    @State private var settingsDestination: SettingsDestination?
    @State private var supportTab: SupportTab = .form
    @State private var supportPresentationID = 0
    // Bumped when the profile photo changes so the cached avatar in the "more" tab is
    // refetched instead of showing the replaced image.
    @State private var profilePhotoVersion: Int64 = 0
    // Auth status intentionally stays small and does not contain profile-photo
    // metadata. Home/My Info publish the full member payload when available;
    // nil keeps the single More avatar backward-compatible until then.
    @State private var hasProfilePhoto: Bool?
    @State private var showsNotifications = false
    @State private var notificationTargetID: NotificationID?
    @State private var notificationDropdownReadPolicy = RootNotificationDropdownReadPolicy()
    @State private var showsUnsupportedLink = false
    @State private var showsLogoutConfirmation = false
    @State private var isLoggingOut = false

    var body: some View {
        // The banner is stacked above the tab content rather than attached with
        // `safeAreaInset`: the tabs' UIKit navigation bars do not adopt a safe-area
        // inset applied outside the `TabView`, so the banner would paint on top of
        // the header instead of pushing it down.
        VStack(spacing: 0) {
            if authenticatedMember?.isImpersonating == true {
                ImpersonationBanner()
            }
            rootContent
        }
        .tint(DPColor.accent)
    }

    private var rootContent: some View {
        ZStack(alignment: .topTrailing) {
            TabView(selection: tabSelection) {
                homeTab
                primaryTab(.calendar, path: $calendarPath, showsNavigationBar: true) {
                    CalendarView(currentMonthRequestID: calendarCurrentMonthRequestID)
                        .navigationDestination(for: MemberCalendarRoute.self) { route in
                            memberCalendar(route)
                        }
                }
                primaryTab(.todo, showsNavigationBar: true) {
                    TodoView(initialTodoID: todoTarget) {
                        todoTarget = nil
                    }
                }
                primaryTab(.team, path: $teamPath, showsNavigationBar: true) {
                    if session.availability.isOffline {
                        RootOnlineRequiredView(feature: .team)
                    } else {
                        TeamView(onOpenCalendar: openMemberCalendar)
                            .navigationDestination(for: MemberCalendarRoute.self) { route in
                                memberCalendar(route)
                            }
                    }
                }
                // The tab bar already names this tab, and the menu carries no toolbar of
                // its own, so an empty navigation bar would only push the list down.
                primaryTab(.more, path: $morePath) {
                    MoreView(
                        profile: moreProfile,
                        onOpenMyInfo: openMyInfo,
                        onSelect: openMoreMenuItem
                    )
                    .navigationDestination(for: MoreDestination.self) { destination in
                        moreDestinationView(destination)
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
        .fullScreenCover(
            isPresented: Binding(
                get: { showsLogoutConfirmation },
                set: { isPresented in
                    if !isPresented,
                       RootLogoutConfirmationPolicy.canDismiss(isLoggingOut: isLoggingOut) {
                        showsLogoutConfirmation = false
                    }
                }
            )
        ) {
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { showsLogoutConfirmation = false },
                canDismiss: RootLogoutConfirmationPolicy.canDismiss(isLoggingOut: isLoggingOut),
                onDismissRequest: { _ in
                    guard RootLogoutConfirmationPolicy.canDismiss(isLoggingOut: isLoggingOut)
                    else { return }
                    showsLogoutConfirmation = false
                    DPHapticCenter.shared.emit(.routine)
                },
                // Confirmation buttons already acknowledge their press. Backdrop and
                // VoiceOver dismissal requests emit the routine event above instead.
                dismissHaptic: nil
            ) { availableSize, dismiss in
                DPConfirmationPanel(
                    title: SettingsLocalization.string("settings.logout.confirmTitle"),
                    message: SettingsLocalization.string("settings.logout.confirmMessage"),
                    confirmTitle: SettingsLocalization.string("settings.logout"),
                    cancelTitle: SettingsLocalization.string("settings.action.cancel"),
                    isDestructive: true,
                    isWorking: isLoggingOut,
                    maximumHeight: availableSize.height,
                    cancel: dismiss,
                    confirm: { logout(dismiss: dismiss) }
                )
            }
            .interactiveDismissDisabled(isLoggingOut)
        }
        .task {
            offlineNetworkMonitor.start()
            applyOfflineDefaultTabIfNeeded()
            await startOnlineWorkIfAllowed()
            await recoverConnectivityIfReachable()
        }
        .onDisappear {
            notifications.stopPolling()
            offlineSyncCoordinator.cancelAll()
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                await RootSceneLifecycleAction.perform(
                    isActive: phase == .active,
                    isNetworkAvailable: session.availability == .online
                        && offlineNetworkMonitor.status != .unsatisfied,
                    setNotificationForeground: {
                        await notifications.setForeground($0)
                    },
                    refreshHome: refreshHomeIfStale,
                    refreshConsent: refreshConsentIfNeeded,
                    resumePush: {
                        await APNsRegistrationManager.shared.resumeRegistration()
                    },
                    consumePendingPush: { await openPendingPushIfNeeded() }
                )
                guard phase == .active else { return }
                await recoverConnectivityIfReachable()
            }
        }
        .onChange(of: offlineNetworkMonitor.status) { _, status in
            guard status == .satisfied else { return }
            Task { await recoverConnectivityIfReachable() }
        }
        .onChange(of: session.availability) { _, availability in
            applyOfflineDefaultTabIfNeeded()
            guard availability == .online else { return }
            Task { await startOnlineWorkIfAllowed() }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .home {
                refreshHomeIfStale()
            }
        }
        .onChange(of: showsNotifications) { _, isPresented in
            guard isPresented else { return }
            notificationDropdownReadPolicy.prepareForOpen()
            Task {
                let didLoad = await notifications.refreshIfStale()
                notificationDropdownReadPolicy.finishLoading(
                    didLoad: didLoad,
                    isPresented: showsNotifications,
                    hasUnread: notifications.unreadCount > 0
                        || notifications.notifications.contains(where: { !$0.isRead })
                )
            }
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
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            Group {
                if session.availability.isOffline {
                    RootOnlineRequiredView(feature: .home)
                } else {
                    HomeView(
                        refreshID: homeRefreshID,
                        onRoute: openHomeRoute,
                        onProfilePhotoStateChanged: { hasPhoto, version in
                            hasProfilePhoto = hasPhoto
                            profilePhotoVersion = version
                        }
                    )
                }
            }
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("screen.home")
                .toolbar {
                    DPDashboardHeaderToolbarItem(placement: .topBarLeading) {
                        DPBrandMark(action: openHome)
                    }
                    DPDashboardHeaderToolbarItem(placement: .topBarTrailing) {
                        notificationBell
                            .fixedSize(horizontal: true, vertical: false)
                    }
                }
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .notifications:
                        if session.availability.isOffline {
                            RootOnlineRequiredView(feature: .notifications)
                        } else {
                            notificationCenter(targetID: $notificationTargetID)
                        }
                    case .friends:
                        if session.availability.isOffline {
                            RootOnlineRequiredView(feature: .social)
                        } else {
                            SocialView(
                                onMutation: socialDidMutate,
                                onOpenCalendar: openMemberCalendar
                            )
                        }
                    case .memberCalendar(let route):
                        memberCalendar(route)
                    }
                }
        }
        .primaryTabItem(.home)
    }

    private func applyOfflineDefaultTabIfNeeded() {
        guard !didApplyOfflineDefaultTab else { return }
        didApplyOfflineDefaultTab = true
        let nextTab = RootOfflineDefaultTabPolicy.selectedTab(
            availability: session.availability,
            current: selectedTab,
            hasApplied: false
        )
        if nextTab != selectedTab {
            selectedTab = nextTab
            homePath.removeAll()
        }
    }

    private func startOnlineWorkIfAllowed() async {
        guard session.availability == .online,
              offlineNetworkMonitor.status != .unsatisfied,
              let accountID = authenticatedMemberID
        else { return }

        if !didStartOnlineWork {
            didStartOnlineWork = true
            await RootAuthenticatedStartupAction.perform(
                isOffline: false,
                startPolling: { notifications.startPolling() },
                refreshNotifications: { await notifications.refresh() },
                activatePush: {
                    await APNsRegistrationManager.shared.activateForAuthenticatedSession()
                },
                consumePendingPush: { await openPendingPushIfNeeded() },
                consumePendingDestination: openPendingDestinationIfNeeded
            )
        }
        guard session.availability == .online,
              authenticatedMemberID == accountID
        else { return }
        await notifications.setForeground(scenePhase == .active)
        await openPendingPushIfNeeded()
        await offlineSyncCoordinator.synchronize(
            accountID: accountID,
            networkStatus: offlineNetworkMonitor.status == .unsatisfied
                ? .unsatisfied
                : .satisfied
        )
    }

    private func recoverConnectivityIfReachable() async {
        guard offlineNetworkMonitor.status.isSatisfied,
              !isRecoveringConnectivity
        else { return }

        isRecoveringConnectivity = true
        defer { isRecoveringConnectivity = false }
        await RootConnectivityRecoveryAction.perform(
            networkStatus: offlineNetworkMonitor.status,
            availability: { session.availability },
            revalidate: { await session.revalidate() },
            startOnlineWork: { await startOnlineWorkIfAllowed() }
        )
    }

    private func primaryTab<Content: View>(
        _ tab: AppTab,
        showsNavigationBar: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            tabRoot(tab, showsNavigationBar: showsNavigationBar) {
                content()
            }
        }
        .primaryTabItem(tab)
    }

    private func primaryTab<Destination: Hashable, Content: View>(
        _ tab: AppTab,
        path: Binding<[Destination]>,
        showsNavigationBar: Bool = false,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack(path: path) {
            tabRoot(tab, showsNavigationBar: showsNavigationBar) {
                content()
            }
        }
        .primaryTabItem(tab)
    }

    private func tabRoot<Content: View>(
        _ tab: AppTab,
        showsNavigationBar: Bool,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(showsNavigationBar ? .visible : .hidden, for: .navigationBar)
            .accessibilityIdentifier("screen.\(tab.rawValue)")
    }

    // A member calendar is a pushed screen wherever it is opened from, so it carries the
    // navigation bar it needs and pops with the system back affordances.
    private func memberCalendar(_ route: MemberCalendarRoute) -> some View {
        CalendarView(
            memberID: route.memberID,
            date: route.date,
            scheduleID: route.scheduleID,
            isPushed: true
        )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .accessibilityIdentifier("screen.calendar.member")
    }

    private var notificationBell: some View {
        NotificationBellButton(
            store: notifications,
            isPresented: notificationPresentationBinding
        )
    }

    // The notification list is a screen like every other menu entry, so it is pushed onto
    // the stack it was opened from and leaves with the same back affordances.
    private func notificationCenter(targetID: Binding<NotificationID?>) -> some View {
        NotificationCenterView(store: notifications, targetNotificationID: targetID) { route in
            let didOpen = await openNotificationRoute(route)
            if didOpen {
                DPHapticCenter.shared.emit(RootHapticPolicy.notificationNavigationFeedback)
            }
            return didOpen
        }
    }

    private var notificationPresentationBinding: Binding<Bool> {
        Binding(
            get: { showsNotifications },
            set: { isPresented in
                guard !session.availability.isOffline else { return }
                guard isPresented != showsNotifications else { return }
                showsNotifications = isPresented
                DPHapticCenter.shared.emit(RootHapticPolicy.notificationDropdownFeedback)
            }
        )
    }

    private var tabSelection: Binding<AppTab> {
        Binding(
            get: { selectedTab },
            set: { destination in
                if selectedTab == .calendar,
                   destination == .calendar,
                   calendarPath.isEmpty {
                    calendarCurrentMonthRequestID &+= 1
                }
                let feedback = RootHapticPolicy.tabSelectionFeedback(
                    from: selectedTab,
                    to: destination
                )
                popToRoot(destination, origin: .tabBar)
                selectedTab = destination
                if let feedback {
                    DPHapticCenter.shared.emit(feedback)
                }
            }
        )
    }

    // Every tab owns a navigation stack, so a tab-bar tap returns that tab to its root
    // screen; the calendar tab root is the authenticated member's own calendar.
    private func popToRoot(_ tab: AppTab, origin: RootTabSelectionOrigin) {
        guard RootNavigationPolicy.popsToRoot(origin: origin) else { return }
        switch tab {
        case .home:
            homePath.removeAll()
        case .calendar:
            calendarPath.removeAll()
        case .team:
            teamPath.removeAll()
        case .more:
            morePath.removeAll()
        case .todo:
            break
        }
    }

    private func openHome() {
        homePath.removeAll()
        selectedTab = .home
    }

    // Routed entries have no "more" menu behind them, so friend management replaces the
    // home tab root instead of being pushed onto the menu's stack.
    private func openFriends() {
        homePath = [.friends]
        selectedTab = .home
    }

    // The bell lives on the home tab root, so opening the full list from its dropdown
    // pushes onto the home stack: back returns to the dashboard the bell belongs to.
    private func openNotifications() {
        notificationTargetID = nil
        homePath = [.notifications]
        selectedTab = .home
    }

    private func openNotifications(targeting notificationID: NotificationID) {
        // A system push opens the full list without applying the dropdown's
        // mark-all-on-close policy to unrelated notifications.
        notificationDropdownReadPolicy.prepareForOpen()
        showsNotifications = false
        notificationTargetID = notificationID
        homePath = [.notifications]
        selectedTab = .home
    }

    private var moreProfile: MoreProfileSummary? {
        authenticatedMember.map {
            MoreProfileSummary(
                member: $0,
                hasProfilePhoto: hasProfilePhoto,
                profilePhotoVersion: profilePhotoVersion
            )
        }
    }

    private func openMyInfo() {
        DPHapticCenter.shared.emit(.routine)
        morePath.append(.myInfo)
    }

    private func openMoreMenuItem(_ item: MoreMenuItem) {
        if let feedback = RootHapticPolicy.moreMenuFeedback(for: item) {
            DPHapticCenter.shared.emit(feedback)
        }
        switch item {
        case .logout:
            showsLogoutConfirmation = true
        case .notifications, .friends, .guide, .support, .settings:
            guard let destination = RootNavigationPolicy.moreDestination(for: item) else { return }
            openMore(destination)
        }
    }

    @ViewBuilder
    private func moreDestinationView(_ destination: MoreDestination) -> some View {
        switch destination {
        case .notifications:
            if session.availability.isOffline {
                RootOnlineRequiredView(feature: .notifications)
            } else {
                notificationCenter(targetID: .constant(nil))
            }
        case .friends:
            if session.availability.isOffline {
                RootOnlineRequiredView(feature: .social)
            } else {
                SocialView(
                    onMutation: socialDidMutate,
                    onOpenCalendar: openMemberCalendar
                )
            }
        case .guide:
            PublicGuideView()
        case .support:
            SupportView(
                isSignedIn: authenticatedMember != nil,
                initialTab: supportTab
            )
            // The screen owns its tab once it exists, so a notification arriving while
            // support is already open has to rebuild it to land on the history tab.
            .id(supportPresentationID)
        case .myInfo:
            MyInfoView(
                onProfilePhotoChanged: {
                    homeRefreshID &+= 1
                    profilePhotoVersion &+= 1
                },
                onProfilePhotoStateChanged: { hasPhoto, version in
                    hasProfilePhoto = hasPhoto
                    profilePhotoVersion = version
                }
            )
            .navigationTitle(RootChromeLocalization.localizable("root.menu.myInfo"))
            .navigationBarTitleDisplayMode(.inline)
        case .settings:
            SettingsView(destination: $settingsDestination)
                .navigationTitle(RootChromeLocalization.localizable("root.menu.settings"))
                .navigationBarTitleDisplayMode(.inline)
        case .memberCalendar(let route):
            memberCalendar(route)
        }
    }

    // Routed entries have no menu screen behind them, so the requested screen becomes
    // the only thing on the "more" stack instead of stacking on whatever was open.
    private func openMore(
        _ destination: MoreDestination,
        settingsDestination: SettingsDestination? = nil,
        supportTab: SupportTab? = nil
    ) {
        self.settingsDestination = RootNavigationPolicy.settingsDestination(
            for: destination,
            requested: settingsDestination
        )
        self.supportTab = RootNavigationPolicy.supportTab(
            for: destination,
            requested: supportTab
        )
        supportPresentationID = RootNavigationPolicy.supportPresentationID(
            for: destination,
            current: supportPresentationID
        )
        morePath = [destination]
        selectedTab = .more
    }

    private func logout(dismiss: @escaping () -> Void) {
        guard RootLogoutConfirmationPolicy.canSubmit(isLoggingOut: isLoggingOut) else { return }
        isLoggingOut = true

        Task {
            await session.logout()
            isLoggingOut = false
            dismiss()
        }
    }

    private var notificationDropdownLayer: some View {
        ZStack(alignment: .topTrailing) {
            DPColor.overlayScrim
                .background {
                    Rectangle()
                        .fill(DPChrome.overlayMaterial)
                        .opacity(DPChrome.overlayMaterialOpacity)
                }
                .ignoresSafeArea()
                .contentShape(Rectangle())
                .onTapGesture(perform: closeNotificationDropdown)
                .accessibilityLabel(
                    RootChromeLocalization.notifications("notifications.common.close")
                )
                .accessibilityAddTraits(.isButton)
                .accessibilityIdentifier("notifications.dropdown.closeBackground")
                .accessibilityAction { closeNotificationDropdown() }

            NotificationDropdown(
                store: notifications,
                onOpen: openDropdownNotification,
                onViewAll: {
                    closeNotificationDropdown()
                    openNotifications()
                },
                onDismiss: closeNotificationDropdown
            )
            .frame(maxWidth: 384)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.top, DPSpacing.extraSmall)
        }
        .accessibilityAction(.escape) { closeNotificationDropdown() }
        .zIndex(10)
    }

    private func closeNotificationDropdown() {
        closeNotificationDropdown(emitHaptic: true)
    }

    private func closeNotificationDropdown(emitHaptic: Bool) {
        let wasPresented = showsNotifications
        let shouldMarkAllAsRead = notificationDropdownReadPolicy.consumeClose()
        showsNotifications = false
        if wasPresented, emitHaptic {
            DPHapticCenter.shared.emit(RootHapticPolicy.notificationDropdownFeedback)
        }
        guard shouldMarkAllAsRead else { return }
        Task { try? await notifications.markAllAsRead(emitsHaptic: false) }
    }

    private func openDropdownNotification(_ notification: NotificationDTO) async {
        guard let route = await notifications.open(notification) else { return }
        if await openNotificationRoute(route) {
            DPHapticCenter.shared.emit(RootHapticPolicy.notificationNavigationFeedback)
            closeNotificationDropdown(emitHaptic: false)
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

    // The calendar is pushed onto the stack of the tab it was opened from, so back is a
    // real pop to the member card or friend row that opened it.
    private func openMemberCalendar(_ memberID: MemberID) {
        let host = RootNavigationPolicy.memberCalendarHost(for: selectedTab)
        push(MemberCalendarRoute(memberID: memberID), onto: host)
        selectedTab = host
    }

    private func push(_ route: MemberCalendarRoute, onto tab: AppTab) {
        switch tab {
        case .home:
            homePath.append(.memberCalendar(route))
        case .team:
            teamPath.append(route)
        case .more:
            morePath.append(.memberCalendar(route))
        case .calendar, .todo:
            calendarPath.append(route)
        }
    }

    // Routed entries have no in-app screen behind them, so they push onto the calendar
    // tab: back lands on the authenticated member's own calendar instead of a stale
    // origin.
    private func routeToMemberCalendar(_ memberID: MemberID) {
        routeToCalendar(MemberCalendarRoute(memberID: memberID))
    }

    private func routeToCalendar(_ route: MemberCalendarRoute) {
        calendarPath = [route]
        selectedTab = .calendar
    }

    private func socialDidMutate(_ affectsReceivedRequestCount: Bool) async {
        homeRefreshID &+= 1
        if affectsReceivedRequestCount {
            await notifications.refreshFriendRequestCount()
        }
    }

    private func refreshHomeIfStale() {
        guard homeRefreshPolicy.shouldRefreshAutomatically() else { return }
        homeRefreshID &+= 1
    }

    private func openNotificationRoute(_ route: NotificationRoute) async -> Bool {
        switch route {
        case .friends:
            openFriends()
            return true
        case .schedule(let scheduleID), .taggedSchedule(let scheduleID):
            return await openScheduleCalendar(scheduleID, route: route)
        case .member(let memberID):
            routeToMemberCalendar(memberID)
            return true
        case .todo(let todoID):
            todoTarget = todoID
            selectedTab = .todo
            return true
        case .support:
            openMore(.support, supportTab: .history)
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
        routeToCalendar(
            MemberCalendarRoute(
                memberID: RootNavigationPolicy.scheduleMemberID(
                    for: route,
                    authenticatedMemberID: authenticatedMemberID,
                    scheduleOwnerID: schedule.memberId
                ),
                date: DateOnly(rawValue: String(schedule.startDateTime.rawValue.prefix(10))),
                scheduleID: scheduleID
            )
        )
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
            isAuthenticated: authenticatedMemberID != nil,
            isOnline: session.availability == .online
                && offlineNetworkMonitor.status != .unsatisfied,
            isActive: scenePhase == .active,
            consume: pushCenter.consumePendingNotificationID,
            showNotificationCenter: openNotifications(targeting:)
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
            routeToMemberCalendar(memberID)
            return true
        }
        if let destination = RootMoreDeepLinkPolicy.destination(from: url) {
            openMore(
                destination,
                settingsDestination: SettingsDeepLink.destination(from: url),
                supportTab: RootMoreDeepLinkPolicy.supportTab(from: url)
            )
            return true
        }

        switch components.first {
        case "todo":
            selectedTab = .todo
        case "team":
            selectedTab = .team
        case "friends":
            openFriends()
        case "notifications":
            openNotifications()
        case nil:
            openHome()
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

    // Tapping a tab in the tab bar goes to that tab's root screen; a programmatic route
    // keeps the stack it just pushed.
    static func popsToRoot(origin: RootTabSelectionOrigin) -> Bool {
        origin == .tabBar
    }

    // A member calendar is pushed onto the stack of the tab that opened it, so back
    // returns to the screen it was opened from. The todo tab has no entry point, so a
    // calendar reached from it falls back to the calendar tab's own stack.
    static func memberCalendarHost(for tab: AppTab) -> AppTab {
        switch tab {
        case .home, .calendar, .team, .more:
            tab
        case .todo:
            .calendar
        }
    }

    // The "more" tab owns its own navigation stack, so a menu entry with a screen is
    // pushed onto it instead of switching tabs: back returns to the menu it came from.
    static func moreDestination(for item: MoreMenuItem) -> MoreDestination? {
        switch item {
        case .friends:
            .friends
        case .notifications:
            .notifications
        case .guide:
            .guide
        case .support:
            .support
        case .settings:
            .settings
        case .logout:
            nil
        }
    }

    // Settings owns the policy pages, so only navigation that explicitly asks for one
    // may carry it; otherwise a stale request would be pushed again on the next visit.
    static func settingsDestination(
        for destination: MoreDestination,
        requested: SettingsDestination?
    ) -> SettingsDestination? {
        destination == .settings ? requested : nil
    }

    // Only an explicit request asks for one of the history tabs; every other way into
    // support opens the inquiry form, so a stale request cannot follow the member.
    static func supportTab(
        for destination: MoreDestination,
        requested: SupportTab?
    ) -> SupportTab {
        destination == .support ? (requested ?? .form) : .form
    }

    /// Reopening support must rebuild its state even when the requested tab has not
    /// changed, because the member may have switched tabs since the previous route.
    static func supportPresentationID(
        for destination: MoreDestination,
        current: Int
    ) -> Int {
        destination == .support ? current &+ 1 : current
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

nonisolated enum RootChromeLocalization {
    static func localizable(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Localizable", locale: locale)
    }

    static func home(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Home", locale: locale)
    }

    static func notifications(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Notifications", locale: locale)
    }

    static func settings(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Settings", locale: locale)
    }

    static func social(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Social", locale: locale)
    }

    static func impersonationRemaining(_ duration: String, locale: Locale? = nil) -> String {
        let selectedLocale = locale ?? AppLocalization.locale
        return String(
            format: localizable("auth.impersonation.remaining", locale: selectedLocale),
            locale: selectedLocale,
            arguments: [duration]
        )
    }
}

nonisolated enum RootLogoutConfirmationPolicy {
    static func canSubmit(isLoggingOut: Bool) -> Bool {
        !isLoggingOut
    }

    static func canDismiss(isLoggingOut: Bool) -> Bool {
        !isLoggingOut
    }
}

/// Semantic feedback decisions for root-level interactions. Programmatic routes do not
/// call the tab-bar binding or menu callbacks, so keeping these rules at their user-action
/// boundaries prevents navigation driven by a deep link or push notification from buzzing.
nonisolated enum RootHapticPolicy {
    static func tabSelectionFeedback(
        from current: AppTab,
        to destination: AppTab
    ) -> DPHapticKind? {
        current == destination ? nil : .selection
    }

    static func tabSelectionFeedback(origin: RootTabSelectionOrigin) -> DPHapticKind? {
        origin == .tabBar ? .selection : nil
    }

    static func moreMenuFeedback(for item: MoreMenuItem) -> DPHapticKind? {
        // Logout's destructive confirmation button owns the warning feedback. The menu
        // row only presents that confirmation and should not warn twice for one action.
        item == .logout ? nil : .routine
    }

    static let notificationDropdownFeedback = DPHapticKind.routine
    static let notificationNavigationFeedback = DPHapticKind.routine
}

nonisolated enum RootTabSelectionOrigin: Equatable, Sendable {
    case tabBar
    case explicitRoute
}

private enum RootOnlineRequiredFeature {
    case home
    case social
    case team
    case notifications

    var titleKey: String { "root.offline.onlineOnly.\(rawValue).title" }

    var rawValue: String {
        switch self {
        case .home: "home"
        case .social: "social"
        case .team: "team"
        case .notifications: "notifications"
        }
    }
}

private struct RootOnlineRequiredView: View {
    let feature: RootOnlineRequiredFeature

    var body: some View {
        ContentUnavailableView {
            Label(
                RootChromeLocalization.localizable(feature.titleKey),
                systemImage: "wifi.exclamationmark"
            )
        } description: {
            Text(RootChromeLocalization.localizable("root.offline.onlineOnly.message"))
        }
        .accessibilityIdentifier("offline.online-required.\(feature.rawValue)")
    }
}

private enum HomeDestination: Hashable {
    case friends
    case notifications
    case memberCalendar(MemberCalendarRoute)
}

nonisolated enum MoreDestination: Hashable, Sendable {
    case friends
    case notifications
    case guide
    case support
    case myInfo
    case settings
    case memberCalendar(MemberCalendarRoute)
}

/// A member calendar pushed onto a tab's navigation stack. It carries the deep-link
/// details the calendar screen needs, so a schedule notification can highlight its day
/// on the pushed screen instead of replacing a tab root.
nonisolated struct MemberCalendarRoute: Hashable, Sendable {
    var memberID: MemberID?
    var date: DateOnly?
    var scheduleID: ScheduleID?
}

/// Routes first-party links to the "more" tab screen that owns them. The account
/// sections moved to `MyInfoView`, so a member link no longer lands on settings.
nonisolated enum RootMoreDeepLinkPolicy {
    static func destination(
        from url: URL,
        allowedHost: String = "dutypark.o-r.kr"
    ) -> MoreDestination? {
        if let settingsDestination = SettingsDeepLink.destination(
            from: url,
            allowedHost: allowedHost
        ) {
            return destination(for: settingsDestination)
        }
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == allowedHost.lowercased()
        else { return nil }

        let components = url.pathComponents.filter { $0 != "/" }
        // Support is not a preference document, so it opens directly under More
        // instead of going through the settings screen.
        if components == ["support"] {
            return .support
        }
        guard components.first == "member" else { return nil }
        return .myInfo
    }

    // The guide has no dependency on the settings model, so it opens directly under
    // More; the policy screens are rendered by the settings model and stay behind it.
    static func destination(for settingsDestination: SettingsDestination) -> MoreDestination {
        settingsDestination == .guide ? .guide : .settings
    }

    /// The web carries the section in `?tab=`, so a link to either history opens there.
    /// The form needs no request: it is where support opens anyway.
    static func supportTab(
        from url: URL,
        allowedHost: String = "dutypark.o-r.kr"
    ) -> SupportTab? {
        guard destination(from: url, allowedHost: allowedHost) == .support,
              let requested = URLComponents(url: url, resolvingAgainstBaseURL: false)?
                .queryItems?
                .first(where: { $0.name == "tab" })?
                .value?
                .lowercased(),
              let tab = SupportTab(rawValue: requested),
              tab != .form
        else { return nil }
        return tab
    }
}

private struct ImpersonationBanner: View {
    @EnvironmentObject private var session: SessionStore

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            HStack(spacing: 10) {
                Image(systemName: "person.crop.circle.badge.clock")
                VStack(alignment: .leading, spacing: 1) {
                    Text(RootChromeLocalization.localizable("auth.impersonation.active"))
                        .font(.caption.weight(.semibold))
                    if let remaining = session.impersonationRemainingTime(at: context.date) {
                        Text(RootChromeLocalization.impersonationRemaining(Self.duration(remaining)))
                        .font(.caption2.monospacedDigit())
                    }
                }
                Spacer(minLength: 4)
                Button(RootChromeLocalization.settings("settings.managed.restore")) {
                    Task { await session.restoreOriginalAccount() }
                }
                .font(.caption.weight(.semibold))
                .buttonStyle(.bordered)
                .tint(DPColor.warningHover)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity)
            // Opaque so the tab content behind it never shows through, and extended
            // upwards so the status bar strip is tinted with the banner instead of
            // being left unpainted.
            .background(DPColor.warningSoft.ignoresSafeArea(edges: .top))
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(DPColor.warningBorder)
                    .frame(height: 1)
            }
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
    let onDismiss: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var panelDragOffset: CGFloat = 0

    private var displayedNotifications: [NotificationDTO] {
        Array(store.notifications.prefix(10))
    }

    private var hasUnreadDisplayedNotifications: Bool {
        displayedNotifications.contains { !$0.isRead }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Text(RootChromeLocalization.notifications("notifications.title"))
                    .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                    .foregroundStyle(DPColor.textPrimary)

                Spacer(minLength: 0)

                NotificationHeaderActionButton(
                    title: RootChromeLocalization.notifications(
                        "notifications.list.markAllAsReadShort"
                    ),
                    systemImage: "checkmark.circle",
                    accessibilityIdentifier: "notifications.dropdown.markAllAsRead"
                ) {
                    Task { try? await store.markAllAsRead() }
                }
                .disabled(!hasUnreadDisplayedNotifications)
            }
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundTertiary)
            // Keeps the dropdown-wide accessibility identifier from overwriting the
            // header button's own identifier.
            .accessibilityElement(children: .contain)

            Divider().overlay(DPColor.borderPrimary)

            Group {
                if store.isLoading && store.notifications.isEmpty {
                    ProgressView(
                        RootChromeLocalization.notifications("notifications.common.loading")
                    )
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else if store.notifications.isEmpty {
                    Text(RootChromeLocalization.notifications("notifications.common.empty"))
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(maxWidth: .infinity, minHeight: 96)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayedNotifications, id: \.id) { notification in
                                NotificationDropdownRow(notification: notification) {
                                    Task { await onOpen(notification) }
                                }

                                if notification.id != displayedNotifications.last?.id {
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
                    Text(
                        RootChromeLocalization.notifications("notifications.dropdown.viewAll")
                    )
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
            .simultaneousGesture(dismissHandleGesture)
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(alignment: .bottom) {
            dismissHandle
        }
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderSecondary, lineWidth: DPChrome.borderWidth)
        }
        .shadow(color: .black.opacity(0.25), radius: 20, y: 10)
        .shadow(color: .black.opacity(0.15), radius: 6, y: 4)
        .offset(y: panelDragOffset)
        .accessibilityIdentifier("notifications.dropdown")
    }

    private var dismissHandle: some View {
        ZStack(alignment: .bottom) {
            Capsule()
                .fill(DPColor.textMuted)
                .frame(width: 30, height: 4)
                .padding(.bottom, DPSpacing.extraSmall)
        }
        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
        // The 44pt interaction area belongs to the underlying footer row. Keeping
        // this visual overlay out of hit testing preserves the footer's tap action.
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(
            RootChromeLocalization.notifications("notifications.common.close")
        )
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { onDismiss() }
        .accessibilityIdentifier("notifications.dropdown.dismissHandle")
    }

    private var dismissHandleGesture: some Gesture {
        DragGesture(coordinateSpace: .global)
            .onChanged { value in
                panelDragOffset = RootNotificationDropdownSwipePolicy.followOffset(
                    translation: value.translation
                )
            }
            .onEnded { value in
                guard RootNotificationDropdownSwipePolicy.shouldDismiss(
                    translation: value.translation
                ) else {
                    let animation: Animation? = reduceMotion
                        ? nil
                        : .interactiveSpring(response: 0.25, dampingFraction: 0.82)
                    withAnimation(animation) {
                        panelDragOffset = 0
                    }
                    return
                }
                onDismiss()
            }
    }
}

private struct NotificationDropdownRow: View {
    let notification: NotificationDTO
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: DPSpacing.compact) {
                ZStack(alignment: .topTrailing) {
                    NotificationDropdownActorAvatar(notification: notification)

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

nonisolated struct NotificationDropdownActorPhotoRequest {
    let actorID: MemberID
    let hasProfilePhoto: Bool?
    let profilePhotoVersion: Int64

    init?(notification: NotificationDTO) {
        guard let actorID = notification.actorId,
              notification.payload.actor?.hasProfilePhoto != false
        else { return nil }
        self.actorID = actorID
        hasProfilePhoto = notification.payload.actor?.hasProfilePhoto
        profilePhotoVersion = notification.payload.actor?.profilePhotoVersion ?? 0
    }

    var path: String {
        "members/\(actorID)/profile-photo"
    }

    var queryItems: [URLQueryItem] {
        [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: String(profilePhotoVersion)),
        ]
    }

    var cacheIdentity: String {
        "\(actorID)-\(profilePhotoVersion)"
    }
}

private struct NotificationDropdownActorAvatar: View {
    let notification: NotificationDTO
    @State private var image: UIImage?

    var body: some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .frame(width: 36, height: 36)
            .overlay {
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                } else {
                    Image(DPProfileAvatarPresentation.defaultAssetName)
                        .resizable()
                        .scaledToFill()
                        .clipShape(Circle())
                }
            }
            .accessibilityElement()
            .accessibilityLabel(notification.payload.actor?.name ?? "")
            .accessibilityIdentifier(accessibilityIdentifier)
            .task(id: photoRequest?.cacheIdentity) {
                await loadPhoto()
            }
    }

    private var photoRequest: NotificationDropdownActorPhotoRequest? {
        NotificationDropdownActorPhotoRequest(notification: notification)
    }

    private var accessibilityIdentifier: String {
        let state = image == nil ? "fallback" : "photo"
        return "notifications.dropdown.row.\(notification.id.uuidString).avatar.\(state)"
    }

    private func loadPhoto() async {
        guard let photoRequest else {
            image = nil
            return
        }
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-notification-actor-avatar") {
            image = Self.uiTestingProfilePhoto()
            return
        }
#endif
        let data = try? await APIClient.shared.data(
            photoRequest.path,
            queryItems: photoRequest.queryItems
        )
        image = data.flatMap(UIImage.init(data:))
    }

#if DEBUG
    private static func uiTestingProfilePhoto() -> UIImage {
        let size = CGSize(width: 72, height: 72)
        return UIGraphicsImageRenderer(size: size).image { context in
            UIColor.systemIndigo.setFill()
            context.cgContext.fill(CGRect(origin: .zero, size: size))
            let symbol = UIImage(systemName: "person.crop.circle.fill")?
                .withTintColor(.white, renderingMode: .alwaysOriginal)
            symbol?.draw(in: CGRect(x: 10, y: 10, width: 52, height: 52))
        }
    }
#endif
}

private extension View {
    func primaryTabItem(_ tab: AppTab) -> some View {
        tabItem {
            Label {
                Text(tab.localizedTitle)
            } icon: {
                Image(systemName: tab.systemImage)
            }
            .accessibilityIdentifier(tab.accessibilityIdentifier)
        }
        .tag(tab)
    }
}

private struct RootTabViewPreview: PreviewProvider {
    static var previews: some View {
        RootTabView()
    }
}
