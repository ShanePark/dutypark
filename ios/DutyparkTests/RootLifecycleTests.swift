import Foundation
import Testing
@testable import Dutypark

@MainActor
struct RootLifecycleTests {
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
}

private enum StubError: Error {
    case failed
}
