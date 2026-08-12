import SwiftUI

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
    @State private var showsUnsupportedLink = false

    var body: some View {
        TabView(selection: $selectedTab) {
            homeTab
            primaryTab(.calendar) {
                CalendarView(
                    memberID: calendarTarget.memberID,
                    date: calendarTarget.date,
                    scheduleID: calendarTarget.scheduleID
                )
                    .id(calendarTarget)
            }
            primaryTab(.todo) {
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
        .sheet(isPresented: $showsNotifications) {
            NavigationStack {
                NotificationCenterView(store: notifications, onOpen: openNotificationRoute)
            }
        }
        .task {
            notifications.startPolling()
            await notifications.refresh()
            await APNsRegistrationManager.shared.activateForAuthenticatedSession()
            await openPendingPushIfNeeded()
            openPendingDestinationIfNeeded()
        }
        .onDisappear {
            notifications.stopPolling()
        }
        .onChange(of: scenePhase) { _, phase in
            Task {
                await notifications.setForeground(phase == .active)
                guard phase == .active else { return }
                homeRefreshID &+= 1
                await APNsRegistrationManager.shared.resumeRegistration()
                await openPendingPushIfNeeded()
            }
        }
        .onChange(of: selectedTab) { _, tab in
            if tab == .home {
                homeRefreshID &+= 1
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
        .safeAreaInset(edge: .top, spacing: 0) {
            if case .authenticated(let member) = session.state, member.isImpersonating {
                ImpersonationBanner()
            }
        }
    }

    private var homeTab: some View {
        NavigationStack(path: $homePath) {
            HomeView(refreshID: homeRefreshID, onRoute: openHomeRoute)
                .navigationTitle(Text(AppTab.home.navigationTitle))
                .accessibilityIdentifier("screen.home")
                .toolbar {
                    ToolbarItemGroup(placement: .topBarTrailing) {
                        Button {
                            homePath.append(.friends)
                        } label: {
                            Image(systemName: "person.2")
                        }
                        .accessibilityLabel(Text("social.title", tableName: "Social"))

                        notificationBell
                    }
                }
                .navigationDestination(for: HomeDestination.self) { destination in
                    switch destination {
                    case .friends:
                        SocialView(
                            onMutation: socialDidMutate,
                            onOpenCalendar: openMemberCalendar
                        )
                    }
                }
        }
        .primaryTabItem(.home)
    }

    private func primaryTab<Content: View>(
        _ tab: AppTab,
        @ViewBuilder content: () -> Content
    ) -> some View {
        NavigationStack {
            content()
                .navigationTitle(Text(tab.navigationTitle))
                .accessibilityIdentifier("screen.\(tab.rawValue)")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        notificationBell
                    }
                }
        }
        .primaryTabItem(tab)
    }

    private var notificationBell: some View {
        NotificationBellButton(store: notifications, isPresented: $showsNotifications)
    }

    private func openHomeRoute(_ route: HomeRoute) {
        switch route {
        case .memberCalendar(let memberID):
            openMemberCalendar(memberID)
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
        case .schedule(let scheduleID):
            return await openScheduleCalendar(scheduleID)
        case .taggedSchedule(let scheduleID):
            return await openScheduleCalendar(scheduleID, targetMemberID: authenticatedMemberID)
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
        guard case .authenticated(let member) = session.state else { return nil }
        return member.id
    }

    private func openScheduleCalendar(
        _ scheduleID: ScheduleID,
        targetMemberID: MemberID? = nil
    ) async -> Bool {
        guard let schedule: ScheduleBasicInfoDTO = try? await APIClient.shared.request(
            "schedules/\(scheduleID.uuidString)"
        ) else { return false }
        calendarTarget = CalendarTarget(
            memberID: targetMemberID ?? schedule.memberId,
            date: DateOnly(rawValue: String(schedule.startDateTime.rawValue.prefix(10))),
            scheduleID: scheduleID
        )
        selectedTab = .calendar
        return true
    }

    private func openPendingPushIfNeeded() async {
        guard let notificationID = pushCenter.consumePendingNotificationID() else { return }
        do {
            if let route = try await notifications.open(id: notificationID) {
                if !(await openNotificationRoute(route)) {
                    showsNotifications = true
                }
            } else {
                showsNotifications = true
            }
        } catch {
            showsNotifications = true
        }
    }

    private func openPendingDestinationIfNeeded() {
        guard let destination = session.consumePendingDestination() else { return }
        if !open(destination), destination.scheme?.lowercased() == "https",
           destination.host?.lowercased() == "dutypark.o-r.kr" {
            showsUnsupportedLink = true
        }
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

private enum HomeDestination: Hashable {
    case friends
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

private extension View {
    func primaryTabItem(_ tab: AppTab) -> some View {
        tabItem {
            Label {
                Text(tab.tabTitle)
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
