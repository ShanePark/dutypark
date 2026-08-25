import Foundation
import Testing
@testable import Dutypark

@MainActor
struct RootLifecycleTests {
    @Test(arguments: [
        (1, false),
        (2, true),
        (4, true),
    ])
    func interactivePopOnlyBeginsForPushedScreens(
        navigationDepth: Int,
        expected: Bool
    ) {
        #expect(
            DPInteractivePopGesturePolicy.shouldBegin(navigationDepth: navigationDepth) == expected
        )
    }

    @Test
    func pushedScreensThatHideTheSystemBackAffordanceRestoreInteractivePop() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()

        let teamManageSource = try String(
            contentsOf: iosDirectory.appending(path: "Dutypark/Features/Team/TeamManageView.swift"),
            encoding: .utf8
        )
        let loginSource = try String(
            contentsOf: iosDirectory.appending(path: "Dutypark/Features/Auth/LoginView.swift"),
            encoding: .utf8
        )

        #expect(teamManageSource.contains(".navigationBarBackButtonHidden(true)"))
        #expect(teamManageSource.contains(".dpInteractivePopGestureEnabled()"))
        #expect(loginSource.contains(".toolbar(.hidden, for: .navigationBar)"))
        #expect(loginSource.contains(".dpInteractivePopGestureEnabled()"))
    }

    @Test
    func authenticationTransitionFailuresUseASeparateGlobalAlert() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let rootSource = try String(
            contentsOf: iosDirectory.appending(path: "Dutypark/Features/Auth/AppRootView.swift"),
            encoding: .utf8
        )
        let sessionSource = try String(
            contentsOf: iosDirectory.appending(path: "Dutypark/Core/Auth/SessionStore.swift"),
            encoding: .utf8
        )

        #expect(rootSource.contains("authenticationTransitionFailure"))
        #expect(rootSource.contains("auth.transition.failure.title"))
        #expect(rootSource.contains("auth.transition.failure.message"))
        #expect(rootSource.contains("dismissAuthenticationTransitionFailure()"))
        #expect(sessionSource.contains("case impersonationFailed"))
        #expect(sessionSource.contains("authenticationTransitionFailure = .impersonationFailed"))
    }

    @Test
    func automaticHomeRefreshCoalescesImmediateSceneAndTabTriggers() {
        var policy = RootHomeRefreshPolicy()
        let now = Date(timeIntervalSince1970: 1_000)

        let firstTrigger = policy.shouldRefreshAutomatically(at: now)
        let immediateDuplicate = policy.shouldRefreshAutomatically(at: now.addingTimeInterval(1))
        let triggerAfterInterval = policy.shouldRefreshAutomatically(
            at: now.addingTimeInterval(RootHomeRefreshPolicy.minimumAutomaticInterval)
        )

        #expect(firstTrigger)
        #expect(!immediateDuplicate)
        #expect(triggerAfterInterval)
    }

    @Test
    func notificationDropdownArmsReadOnCloseOnlyAfterVisibleSuccessfulUnreadLoad() {
        var policy = RootNotificationDropdownReadPolicy()

        policy.prepareForOpen()
        policy.finishLoading(didLoad: true, isPresented: true, hasUnread: true)

        let shouldMarkAllAsRead = policy.consumeClose()
        #expect(shouldMarkAllAsRead)
    }

    @Test(arguments: [
        (didLoad: false, isPresented: true, hasUnread: true),
        (didLoad: true, isPresented: false, hasUnread: true),
        (didLoad: true, isPresented: true, hasUnread: false),
    ])
    func notificationDropdownDoesNotArmReadOnCloseWithoutVisibleSuccessfulUnreadLoad(
        input: (didLoad: Bool, isPresented: Bool, hasUnread: Bool)
    ) {
        var policy = RootNotificationDropdownReadPolicy()

        policy.prepareForOpen()
        policy.finishLoading(
            didLoad: input.didLoad,
            isPresented: input.isPresented,
            hasUnread: input.hasUnread
        )

        let shouldMarkAllAsRead = policy.consumeClose()
        #expect(!shouldMarkAllAsRead)
    }

    @Test
    func notificationDropdownConsumesReadOnCloseOnlyOnceAndResetsOnReopen() {
        var policy = RootNotificationDropdownReadPolicy()
        policy.prepareForOpen()
        policy.finishLoading(didLoad: true, isPresented: true, hasUnread: true)

        let firstCloseShouldMarkAllAsRead = policy.consumeClose()
        let repeatedCloseShouldMarkAllAsRead = policy.consumeClose()
        #expect(firstCloseShouldMarkAllAsRead)
        #expect(!repeatedCloseShouldMarkAllAsRead)

        policy.prepareForOpen()
        let reopenedCloseShouldMarkAllAsRead = policy.consumeClose()
        #expect(!reopenedCloseShouldMarkAllAsRead)
    }

    @Test
    func authenticatedStartupRunsRequiredWorkInOrder() async {
        var events: [String] = []

        await RootAuthenticatedStartupAction.perform(
            startPolling: { events.append("polling") },
            refreshNotifications: { events.append("refresh") },
            activatePush: { events.append("activate-push") },
            consumePendingPush: { events.append("push") },
            consumePendingDestination: { events.append("destination") }
        )

        #expect(events == [
            "polling",
            "refresh",
            "activate-push",
            "push",
            "destination"
        ])
    }

    @Test
    func inactiveSceneOnlyUpdatesNotificationForegroundState() async {
        var events: [String] = []

        await RootSceneLifecycleAction.perform(
            isActive: false,
            setNotificationForeground: { events.append("foreground-\($0)") },
            refreshHome: { events.append("home") },
            refreshConsent: { events.append("consent-scheduled") },
            resumePush: { events.append("push") },
            consumePendingPush: { events.append("pending-push") }
        )

        #expect(events == ["foreground-false"])
    }

    @Test
    func activeSceneRefreshesRootAndSchedulesConsentBeforePushWork() async {
        var events: [String] = []

        await RootSceneLifecycleAction.perform(
            isActive: true,
            setNotificationForeground: { events.append("foreground-\($0)") },
            refreshHome: { events.append("home") },
            refreshConsent: { events.append("consent-scheduled") },
            resumePush: { events.append("push") },
            consumePendingPush: { events.append("pending-push") }
        )

        #expect(events == [
            "foreground-true",
            "home",
            "consent-scheduled",
            "push",
            "pending-push"
        ])
    }

    @Test
    func offlineStartupSkipsNotificationAndPushNetworkWork() async {
        var events: [String] = []

        await RootAuthenticatedStartupAction.perform(
            isOffline: true,
            startPolling: { events.append("polling") },
            refreshNotifications: { events.append("refresh") },
            activatePush: { events.append("activate-push") },
            consumePendingPush: { events.append("push") },
            consumePendingDestination: { events.append("destination") }
        )

        #expect(events.isEmpty)
    }

    @Test
    func offlineSceneDoesNotSetNotificationForegroundOrRunNetworkWork() async {
        var events: [String] = []

        await RootSceneLifecycleAction.perform(
            isActive: true,
            isNetworkAvailable: false,
            setNotificationForeground: { events.append("foreground-\($0)") },
            refreshHome: { events.append("home") },
            refreshConsent: { events.append("consent") },
            resumePush: { events.append("push") },
            consumePendingPush: { events.append("pending-push") }
        )

        #expect(events == ["foreground-false"])
    }

    @Test
    func connectivityRecoveryRevalidatesOnlyOnSatisfiedPathAndStartsWorkAfterOnline() async {
        var availability = SessionAvailability.offline
        var events: [String] = []

        await RootConnectivityRecoveryAction.perform(
            networkStatus: .satisfied,
            availability: { availability },
            revalidate: {
                events.append("revalidate")
                availability = .online
            },
            startOnlineWork: { events.append("online-work") }
        )

        #expect(events == ["revalidate", "online-work"])
    }

    @Test
    func offlineAuthenticatedLaunchSelectsCalendarOnce() {
        #expect(
            RootOfflineDefaultTabPolicy.selectedTab(
                availability: .offline,
                current: .home,
                hasApplied: false
            ) == .calendar
        )
        #expect(
            RootOfflineDefaultTabPolicy.selectedTab(
                availability: .offline,
                current: .todo,
                hasApplied: true
            ) == .todo
        )
        #expect(
            RootOfflineDefaultTabPolicy.selectedTab(
                availability: .online,
                current: .home,
                hasApplied: false
            ) == .home
        )
    }

    @Test
    func pendingPushOpensTheIdentifierProvidedByTheConsumer() async {
        let notificationID = UUID()
        var openedIDs: [UUID] = []
        var fallbackCount = 0

        await RootPendingPushAction.perform(
            consume: { notificationID },
            open: {
                openedIDs.append($0)
                return true
            },
            showFallback: { fallbackCount += 1 }
        )

        #expect(openedIDs == [notificationID])
        #expect(fallbackCount == 0)
    }

    @Test
    func pendingPushDoesNothingWhenTheConsumerProvidesNoIdentifier() async {
        var openCount = 0
        var fallbackCount = 0

        await RootPendingPushAction.perform(
            consume: { nil },
            open: { _ in
                openCount += 1
                return true
            },
            showFallback: { fallbackCount += 1 }
        )

        #expect(openCount == 0)
        #expect(fallbackCount == 0)
    }

    @Test(arguments: [false, true])
    func pendingPushFallsBackWhenRouteCannotOpen(orThrows: Bool) async {
        let notificationID = UUID()
        var fallbackCount = 0

        await RootPendingPushAction.perform(
            consume: { notificationID },
            open: { _ in
                if orThrows { throw StubError.failed }
                return false
            },
            showFallback: { fallbackCount += 1 }
        )

        #expect(fallbackCount == 1)
    }

    @Test
    func pendingDestinationIsConsumedOnceAndOpened() {
        let destination = URL(string: "https://dutypark.o-r.kr/todo")!
        var pendingDestination: URL? = destination
        var opened: [URL] = []
        var unsupportedCount = 0

        RootPendingDestinationAction.perform(
            consume: {
                defer { pendingDestination = nil }
                return pendingDestination
            },
            open: {
                opened.append($0)
                return true
            },
            showUnsupported: { unsupportedCount += 1 }
        )
        RootPendingDestinationAction.perform(
            consume: {
                defer { pendingDestination = nil }
                return pendingDestination
            },
            open: {
                opened.append($0)
                return true
            },
            showUnsupported: { unsupportedCount += 1 }
        )

        #expect(opened == [destination])
        #expect(unsupportedCount == 0)
    }

    @Test
    func unsupportedFirstPartyPendingDestinationShowsFeedback() {
        let destination = URL(string: "https://dutypark.o-r.kr/not-supported")!
        var unsupportedCount = 0

        RootPendingDestinationAction.perform(
            consume: { destination },
            open: { _ in false },
            showUnsupported: { unsupportedCount += 1 }
        )

        #expect(unsupportedCount == 1)
    }

    @Test
    func rejectedForeignPendingDestinationDoesNotShowFirstPartyFeedback() {
        let destination = URL(string: "https://example.com/todo")!
        var unsupportedCount = 0

        RootPendingDestinationAction.perform(
            consume: { destination },
            open: { _ in false },
            showUnsupported: { unsupportedCount += 1 }
        )

        #expect(unsupportedCount == 0)
    }

    @Test
    func launchArgumentsSelectOnlyExplicitUITestSessionOverrides() {
        #expect(DutyparkLaunchPolicy.initialSessionState(arguments: []) == .restoring)
        #expect(
            DutyparkLaunchPolicy.initialSessionState(arguments: ["-ui-testing-guest"])
                == .guest
        )
        guard case .authenticated(let member) = DutyparkLaunchPolicy.initialSessionState(
            arguments: ["-ui-testing-authenticated"]
        ) else {
            Issue.record("Expected authenticated UI-test state")
            return
        }
        #expect(member.id == 1)
        #expect(member.email == "test@duty.park")
    }

    @Test
    func launchArgumentsProvideDeterministicImpersonationFixture() {
        let arguments = ["-ui-testing-authenticated", "-ui-testing-impersonating"]
        guard case .authenticated(let member) = DutyparkLaunchPolicy.initialSessionState(
            arguments: arguments
        ) else {
            Issue.record("Expected authenticated UI-test state")
            return
        }
        #expect(member.isImpersonating)
        #expect(member.originalMemberId == 1)
        #expect(member.id == 2)

        let now = Date(timeIntervalSince1970: 1_700_000_000)
        #expect(
            DutyparkLaunchPolicy.initialImpersonationExpiration(arguments: arguments, now: now)
                == now.addingTimeInterval(600)
        )
        #expect(
            DutyparkLaunchPolicy.initialImpersonationExpiration(
                arguments: ["-ui-testing-authenticated"],
                now: now
            ) == nil
        )
    }
}

private enum StubError: Error {
    case failed
}
