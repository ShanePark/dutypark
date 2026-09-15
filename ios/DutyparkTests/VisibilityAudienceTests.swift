import XCTest
@testable import Dutypark

@MainActor
final class VisibilityAudienceTests: XCTestCase {
    private func friend(_ id: MemberID, _ name: String, family: Bool = false) -> FriendDTO {
        FriendDTO(id: id, name: name, teamId: nil, team: nil, hasProfilePhoto: false, profilePhotoVersion: 0, isFamily: family, pinOrder: nil)
    }

    private func snapshot(visibility: Visibility = .friends, ownerID: MemberID = 1) -> VisibilityAudienceSnapshot {
        VisibilityAudienceSnapshot(ownerID: ownerID, calendarVisibility: visibility, friends: [
            friend(1, "Owner"), friend(2, "Friend"), friend(3, "Family", family: true), friend(2, "Duplicate"),
        ])
    }

    private func context(_ visibility: Visibility = .friends, scope: VisibilityAudienceScope = .calendar) -> VisibilityAudienceContext {
        VisibilityAudienceContext(ownerID: 1, visibility: visibility, scope: scope)
    }

    func testFriendsIncludeFamilyButExcludeOwnerAndDuplicateIdentities() {
        XCTAssertEqual(VisibilityAudiencePolicy.members(in: snapshot(), context: context()).map(\.id), [2, 3])
    }

    func testFamilyContainsOnlyAcceptedFamilyRelationships() {
        XCTAssertEqual(VisibilityAudiencePolicy.members(in: snapshot(), context: context(.family)).map(\.id), [3])
    }

    func testCalendarPreviewUsesProposedVisibilityNotCurrentlySavedVisibility() {
        XCTAssertEqual(VisibilityAudiencePolicy.members(in: snapshot(visibility: .privateAccess), context: context()).map(\.id), [2, 3])
    }

    func testScheduleAudienceIntersectsBothVisibilityGates() {
        XCTAssertEqual(VisibilityAudiencePolicy.members(in: snapshot(visibility: .family), context: context(scope: .schedule)).map(\.id), [3])
        XCTAssertTrue(VisibilityAudiencePolicy.members(in: snapshot(visibility: .privateAccess), context: context(scope: .schedule)).isEmpty)
        XCTAssertEqual(VisibilityAudiencePolicy.members(in: snapshot(visibility: .publicAccess), context: context(.family, scope: .schedule)).map(\.id), [3])
    }

    func testPrivatePublicUnknownAndMismatchedOwnersDoNotEnumerateAnAudience() {
        for visibility in [Visibility.publicAccess, .privateAccess, .unknown("FUTURE")] {
            XCTAssertTrue(VisibilityAudiencePolicy.members(in: snapshot(), context: context(visibility)).isEmpty)
        }
        XCTAssertTrue(VisibilityAudiencePolicy.members(in: snapshot(ownerID: 9), context: context()).isEmpty)
        XCTAssertTrue(VisibilityAudiencePolicy.members(in: snapshot(visibility: .unknown("FUTURE")), context: context(scope: .schedule)).isEmpty)
    }

    func testSearchTrimsAndNormalizesNamesWithoutChangingTheSource() {
        let people = [friend(3, "Family", family: true), friend(2, "가족")]
        XCTAssertEqual(VisibilityAudiencePolicy.search(people, query: "  FAMILY ", locale: Locale(identifier: "en")).map(\.id), [3])
        XCTAssertEqual(VisibilityAudiencePolicy.search(people, query: "가족".decomposedStringWithCanonicalMapping, locale: Locale(identifier: "ko")).map(\.id), [2])
        XCTAssertTrue(VisibilityAudiencePolicy.search(people, query: "missing", locale: .current).isEmpty)
        XCTAssertEqual(people.map(\.id), [3, 2])
    }

    func testFailedLoadIsNotPresentedAsASuccessfulEmptyAudience() async {
        let model = VisibilityAudienceModel { throw APIError.transport }
        await model.load(context())
        XCTAssertEqual(model.status, .error)
        XCTAssertTrue(model.members(for: context()).isEmpty)

        let empty = VisibilityAudienceSnapshot(ownerID: 1, calendarVisibility: .friends, friends: [])
        let emptyModel = VisibilityAudienceModel { empty }
        await emptyModel.load(context())
        XCTAssertEqual(emptyModel.status, .ready)
        XCTAssertTrue(emptyModel.members(for: context()).isEmpty)
    }

    func testDifferentAccountResponseIsRejected() async {
        let value = snapshot(ownerID: 9)
        let model = VisibilityAudienceModel { value }
        await model.load(context())
        XCTAssertEqual(model.status, .error)
        XCTAssertNil(model.snapshot)
    }

    func testClosingOrChangingAccountDiscardsAnInFlightResponse() async {
        let gate = AudiencePendingResponse()
        let model = VisibilityAudienceModel { try await gate.load() }
        let requested = context()
        let task = Task { await model.load(requested) }
        await gate.waitUntilRequested()
        model.reset()
        await gate.succeed(snapshot())
        await task.value
        XCTAssertEqual(model.status, .idle)
        XCTAssertNil(model.snapshot)
        XCTAssertTrue(model.members(for: requested).isEmpty)
    }

    func testAReadySnapshotIsNotVisibleUnderAnotherScopeOrAccount() async {
        let value = snapshot()
        let model = VisibilityAudienceModel { value }
        await model.load(context())
        XCTAssertEqual(model.members(for: context()).count, 2)
        XCTAssertTrue(model.members(for: context(.family)).isEmpty)
        XCTAssertTrue(model.members(for: VisibilityAudienceContext(ownerID: 9, visibility: .friends, scope: .calendar)).isEmpty)
    }

    func testRetryCanRecoverFromAnError() async {
        let source = AudienceRetrySource(value: snapshot())
        let model = VisibilityAudienceModel { try await source.load() }
        await model.load(context())
        XCTAssertEqual(model.status, .error)
        await model.load(context())
        XCTAssertEqual(model.status, .ready)
        XCTAssertEqual(model.members(for: context()).map(\.id), [2, 3])
    }
}

private actor AudiencePendingResponse {
    private var continuation: CheckedContinuation<VisibilityAudienceSnapshot, any Error>?
    private var waiters: [CheckedContinuation<Void, Never>] = []
    private var started = false

    func load() async throws -> VisibilityAudienceSnapshot {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            started = true
            waiters.forEach { $0.resume() }
            waiters.removeAll()
        }
    }

    func waitUntilRequested() async {
        if started { return }
        await withCheckedContinuation { waiters.append($0) }
    }

    func succeed(_ value: VisibilityAudienceSnapshot) {
        continuation?.resume(returning: value)
        continuation = nil
    }
}

private actor AudienceRetrySource {
    let value: VisibilityAudienceSnapshot
    private var attempt = 0
    init(value: VisibilityAudienceSnapshot) { self.value = value }
    func load() throws -> VisibilityAudienceSnapshot {
        attempt += 1
        if attempt == 1 { throw APIError.transport }
        return value
    }
}
