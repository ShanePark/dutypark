import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class SocialFeatureTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    func testDestructiveConfirmationsUseCenteredSharedPanel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Social/SocialView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertFalse(source.contains(".alert(item: $confirmation)"))
        XCTAssertTrue(source.contains(".fullScreenCover(item: $confirmation)"))
        XCTAssertTrue(source.contains("DPConfirmationPanel("))
        XCTAssertTrue(source.contains("canDismiss: !isPerformingConfirmation"))
        XCTAssertTrue(source.contains("isWorking: isPerformingConfirmation"))
        XCTAssertTrue(source.contains("isDestructive: confirmation.isDestructive"))
        XCTAssertTrue(source.contains(".alert(item: $candidate)"))
    }

    func testUnblockAndFamilyRequestGoThroughTheConfirmationPanel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Social/SocialView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        // Unblocking undoes a protective action and a family request goes out to somebody
        // else, so neither may fire straight from the tap.
        XCTAssertFalse(source.contains("Task { await viewModel.unblock(member) }"))
        XCTAssertTrue(source.contains("confirmation = .unblock(member)"))
        XCTAssertFalse(source.contains("Task { await viewModel.sendFamilyRequest(to: friend) }"))
        XCTAssertTrue(source.contains("confirmation = .sendFamily(friend)"))
    }

    func testOnlyTheDestructiveConfirmationsAreStyledAsDestructive() {
        let target = DashboardFriendDetailDTO(
            member: MemberPreviewDTO(
                id: 7,
                name: "Nari",
                teamId: nil,
                team: nil,
                hasProfilePhoto: false,
                profilePhotoVersion: 0
            ),
            duty: nil,
            schedules: [],
            isFamily: false,
            pinOrder: nil
        )
        let blocked = BlockedMemberDTO(
            id: 7,
            name: "Nari",
            hasProfilePhoto: false,
            profilePhotoVersion: 0,
            blockedAt: LocalDateTimeValue(rawValue: "2026-08-19T00:00:00")
        )

        XCTAssertTrue(SocialConfirmation.block(target).isDestructive)
        XCTAssertTrue(SocialConfirmation.removeFriend(target).isDestructive)
        XCTAssertFalse(SocialConfirmation.unblock(blocked).isDestructive)
        XCTAssertFalse(SocialConfirmation.sendFamily(target).isDestructive)
    }

    func testConfirmationActionPolicyBlocksDuplicateSubmissions() {
        XCTAssertTrue(
            SocialConfirmationActionPolicy.canBegin(
                isPerformingConfirmation: false,
                isPerformingAction: false
            )
        )
        XCTAssertFalse(
            SocialConfirmationActionPolicy.canBegin(
                isPerformingConfirmation: true,
                isPerformingAction: false
            )
        )
        XCTAssertFalse(
            SocialConfirmationActionPolicy.canBegin(
                isPerformingConfirmation: false,
                isPerformingAction: true
            )
        )
    }

    func testInlinePinnedOrderStringsResolveInEveryLocale() throws {
        let keys = [
            "social.action.moveDown",
            "social.action.moveUp",
            "social.hint.pinnedOrder",
            "social.section.pinnedOrder",
            "social.warning.reorderReload"
        ]

        for locale in ["en", "ko"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Social"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

    func testBlockStringsResolveInEveryLocale() throws {
        let keys = [
            "social.action.block",
            "social.action.unblock",
            "social.blocked.since",
            "social.confirm.block.message",
            "social.confirm.block.title",
            "social.confirm.sendFamily.message",
            "social.confirm.sendFamily.title",
            "social.confirm.unblock.message",
            "social.confirm.unblock.title",
            "social.empty.blocked",
            "social.error.block",
            "social.error.unblock",
            "social.section.blocked"
        ]

        for locale in ["en", "ko"] {
            let url = try XCTUnwrap(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try XCTUnwrap(Bundle(url: url))
            for key in keys {
                XCTAssertNotEqual(
                    bundle.localizedString(forKey: key, value: key, table: "Social"),
                    key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }

    /// The extracted components keep the friend list screen's block entry points,
    /// which SwiftUI leaves unreachable from a unit test.
    func testBlockEntryPointsStayWiredIntoTheExtractedComponents() throws {
        let popover = try Self.projectSource(at: "Dutypark/Features/Social/FriendActionPopover.swift")
        XCTAssertTrue(popover.contains("social.action.block"))
        XCTAssertTrue(popover.contains("onBlock"))

        let socialView = try Self.projectSource(at: "Dutypark/Features/Social/SocialView.swift")
        XCTAssertTrue(socialView.contains("BlockedMembersPanel("))
        XCTAssertTrue(socialView.contains("confirmation = .block(friend)"))
        XCTAssertTrue(socialView.contains("FriendSearchModalView("))
    }

    override func tearDown() {
        SocialURLProtocolStub.handler = nil
        super.tearDown()
    }

    func testRepositoryDecodesDashboardRequestDirections() async throws {
        SocialURLProtocolStub.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/dashboard/friends")
            return Self.response(
                request,
                status: 200,
                body: #"{"friends":[],"pendingRequestsTo":[{"id":1,"fromMember":{"id":11,"name":"Received","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"toMember":{"id":99,"name":"Me","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"status":"PENDING","createdAt":null,"requestType":"FRIEND_REQUEST"}],"pendingRequestsFrom":[{"id":2,"fromMember":{"id":99,"name":"Me","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"toMember":{"id":22,"name":"Sent","teamId":null,"team":null,"hasProfilePhoto":false,"profilePhotoVersion":0},"status":"PENDING","createdAt":null,"requestType":"FAMILY_REQUEST"}]}"#
            )
        }

        let info = try await LiveSocialRepository(client: makeClient()).friendInfo()

        XCTAssertEqual(info.pendingRequestsTo.first?.fromMember.id, 11)
        XCTAssertEqual(info.pendingRequestsFrom.first?.toMember.id, 22)
        XCTAssertEqual(info.pendingRequestsFrom.first?.requestType, .family)
    }

    func testRepositoryUsesExistingSearchAndMutationContracts() async throws {
        let recorder = SocialRequestRecorder()
        SocialURLProtocolStub.handler = { request in
            recorder.append(request)
            let body = if request.url?.path == "/api/friends/search" {
                #"{"content":[],"totalPages":0,"totalElements":0,"last":true,"first":true,"size":5,"number":2,"numberOfElements":0,"empty":true}"#
            } else {
                ""
            }
            return Self.response(request, status: request.url?.path == "/api/friends/search" ? 200 : 204, body: body)
        }

        let repository = LiveSocialRepository(client: makeClient())
        _ = try await repository.search(keyword: "shane park", page: 2, size: 5)
        try await repository.sendFriendRequest(to: 10)
        try await repository.cancelRequest(to: 11)
        try await repository.acceptRequest(from: 12)
        try await repository.rejectRequest(from: 13)
        try await repository.sendFamilyRequest(to: 14)
        try await repository.removeFromFamily(15)
        try await repository.removeFriend(16)
        try await repository.pin(17)
        try await repository.unpin(18)
        try await repository.updatePinnedOrder([18, 17])

        let requests = recorder.requests
        XCTAssertEqual(requests[0].url?.path, "/api/friends/search")
        XCTAssertEqual(
            URLComponents(url: requests[0].url!, resolvingAgainstBaseURL: false)?.queryItems,
            [
                URLQueryItem(name: "keyword", value: "shane park"),
                URLQueryItem(name: "page", value: "2"),
                URLQueryItem(name: "size", value: "5")
            ]
        )
        XCTAssertEqual(requests.dropFirst().map { $0.httpMethod }, [
            "POST", "DELETE", "POST", "POST", "PUT", "DELETE", "DELETE", "PATCH", "PATCH", "PATCH"
        ])
        XCTAssertEqual(requests.dropFirst().map { $0.url!.path }, [
            "/api/friends/request/send/10",
            "/api/friends/request/cancel/11",
            "/api/friends/request/accept/12",
            "/api/friends/request/reject/13",
            "/api/friends/family/14",
            "/api/friends/family/15",
            "/api/friends/16",
            "/api/friends/pin/17",
            "/api/friends/unpin/18",
            "/api/friends/pin/order"
        ])
    }

    func testRepositoryUsesTheBlockEndpointContracts() async throws {
        let recorder = SocialRequestRecorder()
        SocialURLProtocolStub.handler = { request in
            recorder.append(request)
            let isBlockedList = request.url?.path == "/api/blocks" && request.httpMethod == "GET"
            let body = isBlockedList
                ? #"[{"id":41,"name":"Blocked","hasProfilePhoto":true,"profilePhotoVersion":3,"blockedAt":"2026-08-18T09:30:00"}]"#
                : ""
            return Self.response(request, status: isBlockedList ? 200 : 204, body: body)
        }

        let repository = LiveSocialRepository(client: makeClient())
        try await repository.block(41)
        try await repository.unblock(41)
        let blocked = try await repository.blockedMembers()

        let requests = recorder.requests
        XCTAssertEqual(requests.map { $0.httpMethod }, ["POST", "DELETE", "GET"])
        XCTAssertEqual(requests.map { $0.url!.path }, ["/api/blocks/41", "/api/blocks/41", "/api/blocks"])
        XCTAssertEqual(blocked.count, 1)
        XCTAssertEqual(blocked.first?.id, 41)
        XCTAssertEqual(blocked.first?.name, "Blocked")
        XCTAssertEqual(blocked.first?.hasProfilePhoto, true)
        XCTAssertEqual(blocked.first?.profilePhotoVersion, 3)
        XCTAssertEqual(blocked.first?.blockedAt.rawValue, "2026-08-18T09:30:00")
    }

    func testPinnedOrderPayloadUsesArrayJSONShape() throws {
        let payload = try JSONEncoder().encode([MemberID](arrayLiteral: 18, 17))

        XCTAssertEqual(payload, Data("[18,17]".utf8))
    }

    func testViewModelKeepsReceivedAndSentRequestDirections() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)

        await viewModel.load()

        XCTAssertEqual(viewModel.receivedRequests.first?.fromMember.id, 11)
        XCTAssertEqual(viewModel.sentRequests.first?.toMember.id, 22)

        if let received = viewModel.receivedRequests.first {
            await viewModel.accept(received)
        }
        if let sent = viewModel.sentRequests.first {
            await viewModel.cancel(sent)
        }

        XCTAssertEqual(repository.actions, ["accept:11", "cancel:22"])
    }

    func testInlineReorderSavesDropOnlyOnce() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()

        var draftIDs = viewModel.pinnedFriends.compactMap(\.member.id)
        draftIDs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        XCTAssertFalse(repository.actions.contains(where: { $0.hasPrefix("order:") }))

        let didSave = await viewModel.savePinnedOrder(draftIDs)

        XCTAssertTrue(didSave)
        XCTAssertEqual(repository.actions.last, "order:32,31")
        XCTAssertEqual(repository.actions.filter { $0.hasPrefix("order:") }.count, 1)
    }

    func testSixPinnedFriendsReorderSavesExactlyOnceWithoutDashboardReload() async {
        let repository = SocialRepositorySpy(pinnedFriendCount: 6)
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let originalIDs = viewModel.pinnedFriends.compactMap(\.member.id)
        let reorderedIDs: [MemberID] = [32, 33, 31, 34, 35, 36]

        XCTAssertEqual(originalIDs, [31, 32, 33, 34, 35, 36])

        let didSave = await viewModel.savePinnedOrder(reorderedIDs)

        XCTAssertTrue(didSave)
        XCTAssertEqual(viewModel.pinnedFriends.compactMap(\.member.id), reorderedIDs)
        XCTAssertEqual(repository.actions, ["order:32,33,31,34,35,36"])
        XCTAssertEqual(repository.friendInfoRequestCount, 1)
    }

    func testPinnedReorderUsesScrollCompatibleLongPressRecognizer() throws {
        let source = try Self.sharedReorderGestureSource()

        XCTAssertTrue(source.contains("modernPinnedFriendReorderGesture"))
        XCTAssertTrue(source.contains("DPLongPressGestureRecognizer("))
        XCTAssertTrue(source.contains("content.gesture(modernPinnedFriendReorderGesture"))
        XCTAssertTrue(source.contains("onCancelled:"))
    }

    /// The iOS 17 deployment target still has no `UIGestureRecognizerRepresentable`,
    /// so sharing the gesture must not quietly drop the sequenced fallback.
    func testSharedPinnedReorderGestureKeepsTheLegacySequencedFallback() throws {
        let source = try Self.sharedReorderGestureSource()

        XCTAssertTrue(source.contains("LongPressGesture("))
        XCTAssertTrue(source.contains(".sequenced("))
        XCTAssertTrue(source.contains("DragGesture("))
        XCTAssertTrue(source.contains("content.simultaneousGesture(legacyPinnedFriendReorderGesture"))
    }

    /// Friend management and the home dashboard both adopt the shared reorder
    /// gesture rather than keeping private copies of the recognizer wiring.
    func testPinnedListAdoptsTheSharedReorderGesture() throws {
        let social = try Self.projectSource(at: "Dutypark/Features/Social/SocialView.swift")
        XCTAssertTrue(
            social.contains("DPPinnedFriendReorderGesture("),
            "Friend management should adopt the shared reorder gesture"
        )
        XCTAssertFalse(
            social.contains("DPLongPressGestureRecognizer("),
            "Friend management should not re-implement the recognizer wiring"
        )

        let home = try Self.projectSource(at: "Dutypark/Features/Home/HomeView.swift")
        XCTAssertTrue(
            home.contains("DPPinnedFriendReorderGesture("),
            "The home friend rail should reorder pinned friends"
        )
    }

    private static func sharedReorderGestureSource() throws -> String {
        try projectSource(at: "Dutypark/Components/DPPinnedFriendReorder.swift")
    }

    private static func projectSource(at path: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    func testFailedInlineReorderRollsBackAndReportsFailure() async {
        let repository = SocialRepositorySpy(failPinnedOrder: true)
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let originalOrder = viewModel.pinnedFriends.compactMap(\.member.id)
        var draftIDs = originalOrder
        draftIDs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        let didSave = await viewModel.savePinnedOrder(draftIDs)

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.pinnedFriends.compactMap(\.member.id), originalOrder)
        XCTAssertEqual(viewModel.errorKey, "social.error.reorder")
        XCTAssertFalse(viewModel.isReordering)
    }

    func testSuccessfulPinnedOrderDoesNotReloadTheWholeSnapshot() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        var draftIDs = viewModel.pinnedFriends.compactMap(\.member.id)
        draftIDs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        let didSave = await viewModel.savePinnedOrder(draftIDs)

        XCTAssertTrue(didSave)
        XCTAssertEqual(viewModel.pinnedFriends.compactMap(\.member.id), draftIDs)
        XCTAssertNil(viewModel.errorKey)
        XCTAssertEqual(repository.actions.filter { $0.hasPrefix("order:") }.count, 1)
        XCTAssertEqual(repository.friendInfoRequestCount, 1)
        XCTAssertFalse(viewModel.isReordering)
    }

    func testConcurrentPinnedOrderSaveDoesNotSendDuplicateMutation() async {
        let repository = SocialRepositorySpy(pinnedOrderDelayMilliseconds: 100)
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        var draftIDs = viewModel.pinnedFriends.compactMap(\.member.id)
        draftIDs.move(fromOffsets: IndexSet(integer: 0), toOffset: 2)

        let firstSave = Task { await viewModel.savePinnedOrder(draftIDs) }
        while !viewModel.isReordering { await Task.yield() }
        let duplicateResult = await viewModel.savePinnedOrder(draftIDs)
        let firstResult = await firstSave.value

        XCTAssertTrue(firstResult)
        XCTAssertFalse(duplicateResult)
        XCTAssertEqual(repository.actions.filter { $0.hasPrefix("order:") }.count, 1)
    }

    func testInlineReorderRejectsIDsOutsidePinnedFriends() async {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()

        let didSave = await viewModel.savePinnedOrder([32, 33])

        XCTAssertFalse(didSave)
        XCTAssertEqual(viewModel.errorKey, "social.error.reorder")
        XCTAssertFalse(repository.actions.contains(where: { $0.hasPrefix("order:") }))
    }

    func testInlineDragMovesCardAsSoonAsItOverlapsNextCard() {
        let targets = pinnedTargets()

        let reordered = DPPinnedFriendLiveOrder.reordered(
            [31, 32, 33],
            draggedID: 31,
            previewFrame: CGRect(x: 0, y: 20, width: 300, height: 88),
            targets: targets
        )

        XCTAssertEqual(reordered, [32, 31, 33])
    }

    func testInlineDragDoesNotMoveBeforeCardsOverlap() {
        let reordered = DPPinnedFriendLiveOrder.reordered(
            [31, 32, 33],
            draggedID: 31,
            previewFrame: CGRect(x: 0, y: 4, width: 300, height: 88),
            targets: pinnedTargets()
        )

        XCTAssertEqual(reordered, [31, 32, 33])
    }

    func testInlineDragReturnsToOriginalOrderWhenPreviewLeavesOverlap() {
        let original: [MemberID] = [31, 32, 33]
        let targets = pinnedTargets()
        let overlapped = DPPinnedFriendLiveOrder.reordered(
            original,
            draggedID: 31,
            previewFrame: CGRect(x: 0, y: 20, width: 300, height: 88),
            targets: targets
        )
        XCTAssertEqual(overlapped, [32, 31, 33])

        let restored = DPPinnedFriendLiveOrder.reordered(
            original,
            draggedID: 31,
            previewFrame: CGRect(x: 0, y: 4, width: 300, height: 88),
            targets: targets
        )

        XCTAssertEqual(restored, original)
    }

    func testInlineDragCanMovePinnedCardUpMultiplePositions() {
        let reordered = DPPinnedFriendLiveOrder.reordered(
            [31, 32, 33],
            draggedID: 33,
            previewFrame: CGRect(x: 0, y: 0, width: 300, height: 88),
            targets: pinnedTargets()
        )

        XCTAssertEqual(reordered, [33, 31, 32])
    }

    func testInlineDragReordersWithOnlyVisibleLazyStackTargets() {
        let targets = [
            DPPinnedFriendDropTarget(memberID: 31, frame: CGRect(x: 0, y: 0, width: 300, height: 88)),
            DPPinnedFriendDropTarget(memberID: 32, frame: CGRect(x: 0, y: 96, width: 300, height: 88)),
            DPPinnedFriendDropTarget(memberID: 33, frame: CGRect(x: 0, y: 192, width: 300, height: 88)),
            DPPinnedFriendDropTarget(memberID: 34, frame: CGRect(x: 0, y: 288, width: 300, height: 88))
        ]

        let reordered = DPPinnedFriendLiveOrder.reordered(
            [31, 32, 33, 34, 35, 36],
            draggedID: 31,
            previewFrame: CGRect(x: 0, y: 20, width: 300, height: 88),
            targets: targets
        )

        XCTAssertEqual(reordered, [32, 31, 33, 34, 35, 36])
    }

    func testInlineDragRequiresLongPressBeforeMovement() {
        XCTAssertEqual(DPPinnedFriendDragLayout.minimumPressDuration, 0.35)
        XCTAssertEqual(DPPinnedFriendDragLayout.maximumPressDistance, 10)
        XCTAssertEqual(DPPinnedFriendDragLayout.activationDistance, 4)
    }

    func testCompactFriendCardKeepsManagementActionsOutOfTheContentLayout() {
        XCTAssertEqual(SocialFriendCardLayout.panelInset, 12)
        XCTAssertEqual(SocialFriendCardLayout.avatarSize, 56)
        XCTAssertEqual(
            SocialFriendCardLayout.topActionsWidth,
            DPSize.minimumTouchTarget * 2
        )
    }

    func testFriendCardMatchesMobileWebIdentityOnlyDensity() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Social/SocialView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let start = try XCTUnwrap(source.range(of: "    private func friendCard("))
        let end = try XCTUnwrap(
            source.range(
                of: "    private func isPinnedFriendReorderEnabled(",
                range: start.upperBound..<source.endIndex
            )
        )
        let friendCardSource = String(source[start.lowerBound..<end.lowerBound])

        XCTAssertTrue(friendCardSource.contains("friend.member.name"))
        XCTAssertTrue(friendCardSource.contains("friend.isFamily"))
        XCTAssertFalse(friendCardSource.contains("friend.member.team"))
        XCTAssertFalse(friendCardSource.contains("friend.duty"))
        XCTAssertFalse(friendCardSource.contains("friend.schedules"))
        XCTAssertTrue(friendCardSource.contains(".frame(minHeight: 88"))
    }

    func testSuccessfulMutationsReportOnlyReceivedRequestCountEffects() async {
        let repository = SocialRepositorySpy()
        var effects: [Bool] = []
        let viewModel = SocialViewModel(repository: repository) { affectsReceivedRequestCount in
            effects.append(affectsReceivedRequestCount)
        }
        await viewModel.load()

        if let received = viewModel.receivedRequests.first {
            await viewModel.accept(received)
        }
        if let friend = viewModel.friends.first {
            await viewModel.togglePin(friend)
        }

        XCTAssertEqual(effects, [true, false])
    }

    func testKnownMutationsPatchOnlyTheirLocalItemsWithoutReloadingTheSnapshot() async throws {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()

        let received = try XCTUnwrap(viewModel.receivedRequests.first)
        await viewModel.reject(received)
        XCTAssertTrue(viewModel.receivedRequests.isEmpty)

        let sent = try XCTUnwrap(viewModel.sentRequests.first)
        await viewModel.cancel(sent)
        XCTAssertTrue(viewModel.sentRequests.isEmpty)

        let family = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 31 }))
        XCTAssertTrue(family.isFamily)
        await viewModel.removeFromFamily(family)
        XCTAssertFalse(try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 31 })).isFamily)

        let pinned = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 31 }))
        await viewModel.togglePin(pinned)
        XCTAssertNil(viewModel.friends.first(where: { $0.member.id == 31 })?.pinOrder)

        let removed = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 32 }))
        await viewModel.removeFriend(removed)
        XCTAssertFalse(viewModel.friends.contains(where: { $0.member.id == 32 }))

        XCTAssertEqual(repository.friendInfoRequestCount, 1)
    }

    func testFailedKnownMutationRollsBackItsOptimisticUpdate() async throws {
        let repository = SocialRepositorySpy(failingAction: "remove:32")
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let friend = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 32 }))

        await viewModel.removeFriend(friend)

        XCTAssertTrue(viewModel.friends.contains(where: { $0.member.id == 32 }))
        XCTAssertEqual(viewModel.errorKey, "social.error.removeFriend")
        XCTAssertEqual(repository.friendInfoRequestCount, 1)
    }

    func testSuccessfulAcceptIsNotReportedAsFailureWhenReconciliationFails() async throws {
        let repository = SocialRepositorySpy(failReloadAfterMutation: true)
        var effects: [Bool] = []
        let viewModel = SocialViewModel(repository: repository) { effects.append($0) }
        await viewModel.load()
        let request = try XCTUnwrap(viewModel.receivedRequests.first)

        await viewModel.accept(request)

        XCTAssertTrue(viewModel.receivedRequests.isEmpty)
        XCTAssertNil(viewModel.errorKey)
        XCTAssertEqual(effects, [true])
        XCTAssertEqual(repository.friendInfoRequestCount, 2)
    }

    func testBlockingAFriendUnfriendsThemAndAddsThemToTheBlockList() async throws {
        let repository = SocialRepositorySpy()
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        XCTAssertTrue(viewModel.blockedMembers.isEmpty)
        let friend = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 32 }))

        await viewModel.block(friend)

        XCTAssertFalse(viewModel.friends.contains(where: { $0.member.id == 32 }))
        XCTAssertEqual(viewModel.blockedMembers.map(\.id), [32])
        XCTAssertEqual(repository.actions, ["block:32"])
        XCTAssertNil(viewModel.errorKey)
    }

    func testBlockingAFriendWithAReceivedFamilyRequestRefreshesTheRequestBadge() async throws {
        let repository = SocialRepositorySpy(receivedRequestFromMemberID: 32)
        var effects: [Bool] = []
        let viewModel = SocialViewModel(repository: repository) { effects.append($0) }
        await viewModel.load()
        let friend = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 32 }))

        await viewModel.block(friend)

        XCTAssertTrue(viewModel.receivedRequests.isEmpty)
        XCTAssertEqual(effects, [true])
    }

    func testFailedBlockRestoresTheFriendAndReportsTheFailure() async throws {
        let repository = SocialRepositorySpy(failingAction: "block:32")
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let friend = try XCTUnwrap(viewModel.friends.first(where: { $0.member.id == 32 }))

        await viewModel.block(friend)

        XCTAssertTrue(viewModel.friends.contains(where: { $0.member.id == 32 }))
        XCTAssertTrue(viewModel.blockedMembers.isEmpty)
        XCTAssertEqual(viewModel.errorKey, "social.error.block")
    }

    func testUnblockingRemovesTheMemberFromTheBlockList() async throws {
        let repository = SocialRepositorySpy(blockedMemberIDs: [32])
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let blocked = try XCTUnwrap(viewModel.blockedMembers.first)

        XCTAssertFalse(viewModel.friends.contains(where: { $0.member.id == 32 }))

        await viewModel.unblock(blocked)

        XCTAssertTrue(viewModel.blockedMembers.isEmpty)
        XCTAssertEqual(repository.actions, ["unblock:32"])
        XCTAssertNil(viewModel.errorKey)
    }

    func testFailedUnblockRestoresTheBlockList() async throws {
        let repository = SocialRepositorySpy(failingAction: "unblock:32", blockedMemberIDs: [32])
        let viewModel = SocialViewModel(repository: repository)
        await viewModel.load()
        let blocked = try XCTUnwrap(viewModel.blockedMembers.first)

        await viewModel.unblock(blocked)

        XCTAssertEqual(viewModel.blockedMembers.map(\.id), [32])
        XCTAssertEqual(viewModel.errorKey, "social.error.unblock")
    }

    private func makeClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SocialURLProtocolStub.self]
        return APIClient(baseURL: baseURL, session: URLSession(configuration: configuration))
    }

    private func pinnedTargets() -> [DPPinnedFriendDropTarget] {
        [
            DPPinnedFriendDropTarget(memberID: 31, frame: CGRect(x: 0, y: 0, width: 300, height: 88)),
            DPPinnedFriendDropTarget(memberID: 32, frame: CGRect(x: 0, y: 96, width: 300, height: 88)),
            DPPinnedFriendDropTarget(memberID: 33, frame: CGRect(x: 0, y: 192, width: 300, height: 88))
        ]
    }

    nonisolated private static func response(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: nil)!,
            Data(body.utf8)
        )
    }
}

private final class SocialRepositorySpy: SocialRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let failPinnedOrder: Bool
    private let failReloadAfterMutation: Bool
    private let failingAction: String?
    private let pinnedOrderDelayMilliseconds: Int64
    private let pinnedFriendCount: Int?
    private let receivedRequestFromMemberID: MemberID
    private var storedActions: [String] = []
    private var didPerformMutation = false
    private var storedFriendInfoRequestCount = 0
    private var storedBlockedMemberIDs: [MemberID]

    init(
        failPinnedOrder: Bool = false,
        failReloadAfterMutation: Bool = false,
        failingAction: String? = nil,
        pinnedOrderDelayMilliseconds: Int64 = 0,
        pinnedFriendCount: Int? = nil,
        blockedMemberIDs: [MemberID] = [],
        receivedRequestFromMemberID: MemberID = 11
    ) {
        self.failPinnedOrder = failPinnedOrder
        self.failReloadAfterMutation = failReloadAfterMutation
        self.failingAction = failingAction
        self.pinnedOrderDelayMilliseconds = pinnedOrderDelayMilliseconds
        self.pinnedFriendCount = pinnedFriendCount
        self.storedBlockedMemberIDs = blockedMemberIDs
        self.receivedRequestFromMemberID = receivedRequestFromMemberID
    }

    var actions: [String] {
        lock.withLock { storedActions }
    }

    var friendInfoRequestCount: Int {
        lock.withLock { storedFriendInfoRequestCount }
    }

    func friendInfo() async throws -> DashboardFriendInfoDTO {
        let shouldFail = lock.withLock {
            storedFriendInfoRequestCount += 1
            return failReloadAfterMutation && didPerformMutation
        }
        if shouldFail { throw SocialTestError.reload }
        let friends = if let pinnedFriendCount {
            (0..<pinnedFriendCount).map { index in
                friend(id: 31 + MemberID(index), pinOrder: Int64(index + 1))
            }
        } else {
            [
                friend(id: 31, pinOrder: 1, isFamily: true),
                friend(id: 32, pinOrder: 2),
                friend(id: 33, pinOrder: nil)
            ]
        }
        // The server unfriends a blocked member, so the dashboard drops them too.
        let blockedIDs = Set(lock.withLock { storedBlockedMemberIDs })
        return DashboardFriendInfoDTO(
            friends: friends.filter { !blockedIDs.contains($0.member.id ?? -1) },
            pendingRequestsTo: blockedIDs.contains(receivedRequestFromMemberID)
                ? []
                : [request(id: 1, from: receivedRequestFromMemberID, to: 99)],
            pendingRequestsFrom: [request(id: 2, from: 99, to: 22)]
        )
    }

    func search(keyword: String, page: Int, size: Int) async throws -> PageResponse<MemberPreviewDTO> {
        throw APIError.transport
    }

    func sendFriendRequest(to memberID: MemberID) async throws { try perform("send:\(memberID)") }
    func cancelRequest(to memberID: MemberID) async throws { try perform("cancel:\(memberID)") }
    func acceptRequest(from memberID: MemberID) async throws { try perform("accept:\(memberID)") }
    func rejectRequest(from memberID: MemberID) async throws { try perform("reject:\(memberID)") }
    func sendFamilyRequest(to memberID: MemberID) async throws { try perform("family:\(memberID)") }
    func removeFromFamily(_ memberID: MemberID) async throws { try perform("demote:\(memberID)") }
    func removeFriend(_ memberID: MemberID) async throws { try perform("remove:\(memberID)") }
    func pin(_ memberID: MemberID) async throws { try perform("pin:\(memberID)") }
    func unpin(_ memberID: MemberID) async throws { try perform("unpin:\(memberID)") }
    func block(_ memberID: MemberID) async throws {
        try perform("block:\(memberID)")
        lock.withLock {
            if !storedBlockedMemberIDs.contains(memberID) {
                storedBlockedMemberIDs.append(memberID)
            }
        }
    }

    func unblock(_ memberID: MemberID) async throws {
        try perform("unblock:\(memberID)")
        lock.withLock { storedBlockedMemberIDs.removeAll { $0 == memberID } }
    }

    func blockedMembers() async throws -> [BlockedMemberDTO] {
        lock.withLock { storedBlockedMemberIDs }.map {
            BlockedMemberDTO(
                id: $0,
                name: "Member \($0)",
                hasProfilePhoto: false,
                profilePhotoVersion: 0,
                blockedAt: LocalDateTimeValue(rawValue: "2026-08-18T09:30:00")
            )
        }
    }

    func updatePinnedOrder(_ memberIDs: [MemberID]) async throws {
        record("order:\(memberIDs.map(String.init).joined(separator: ","))")
        if pinnedOrderDelayMilliseconds > 0 {
            try await Task.sleep(for: .milliseconds(pinnedOrderDelayMilliseconds))
        }
        if failPinnedOrder { throw SocialTestError.reorder }
        lock.withLock {
            didPerformMutation = true
        }
    }

    private func record(_ action: String) {
        lock.withLock { storedActions.append(action) }
    }

    private func perform(_ action: String) throws {
        let shouldFail = lock.withLock {
            storedActions.append(action)
            didPerformMutation = true
            return failingAction == action
        }
        if shouldFail { throw SocialTestError.mutation }
    }

    private func member(_ id: MemberID) -> MemberPreviewDTO {
        MemberPreviewDTO(
            id: id,
            name: "Member \(id)",
            teamId: nil,
            team: nil,
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
    }

    private func friend(
        id: MemberID,
        pinOrder: Int64?,
        isFamily: Bool = false
    ) -> DashboardFriendDetailDTO {
        DashboardFriendDetailDTO(
            member: member(id),
            duty: nil,
            schedules: [],
            isFamily: isFamily,
            pinOrder: pinOrder
        )
    }

    private func request(id: Int64, from: MemberID, to: MemberID) -> FriendRequestDTO {
        FriendRequestDTO(
            id: id,
            fromMember: member(from),
            toMember: member(to),
            status: .pending,
            createdAt: nil,
            requestType: .friend
        )
    }
}

private enum SocialTestError: Error {
    case reorder
    case reload
    case mutation
}

private final class SocialRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { storedRequests }
    }

    func append(_ request: URLRequest) {
        lock.withLock { storedRequests.append(request) }
    }
}

private final class SocialURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else { fatalError("Missing SocialURLProtocolStub handler") }
        let (response, data) = handler(request)
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
