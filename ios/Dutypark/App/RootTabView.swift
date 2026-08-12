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
    @State private var showsNotificationCenter = false
    @State private var showsUnsupportedLink = false

    var body: some View {
        ZStack(alignment: .topTrailing) {
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
                        brandMark
                    }
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
                .navigationTitle("")
                .navigationBarTitleDisplayMode(.inline)
                .accessibilityIdentifier("screen.\(tab.rawValue)")
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        brandMark
                    }
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

    private var brandMark: some View {
        DPBrandMark {
            homePath.removeAll()
            selectedTab = .home
        }
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
