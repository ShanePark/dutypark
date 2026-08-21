import CoreGraphics
import Testing
@testable import Dutypark

struct HomeFriendRailDragPolicyTests {
    @Test
    func edgesChooseTheOppositeRailScrollDirection() {
        let viewport = CGRect(x: 40, y: 100, width: 320, height: 180)

        #expect(HomeFriendRailDragPolicy.autoScrollDirection(
            location: CGPoint(x: 45, y: 180),
            initialLocation: CGPoint(x: 200, y: 180),
            viewport: viewport
        ) == .backward)
        #expect(HomeFriendRailDragPolicy.autoScrollDirection(
            location: CGPoint(x: 355, y: 180),
            initialLocation: CGPoint(x: 200, y: 180),
            viewport: viewport
        ) == .forward)
        #expect(HomeFriendRailDragPolicy.autoScrollDirection(
            location: CGPoint(x: 200, y: 180),
            initialLocation: CGPoint(x: 200, y: 180),
            viewport: viewport
        ) == nil)
    }

    @Test
    func stationaryOrOppositeMovementAtAnEdgeDoesNotAutoScroll() {
        let viewport = CGRect(x: 40, y: 100, width: 320, height: 180)

        #expect(HomeFriendRailDragPolicy.autoScrollDirection(
            location: CGPoint(x: 350, y: 180),
            initialLocation: CGPoint(x: 350, y: 180),
            viewport: viewport
        ) == nil)
        #expect(HomeFriendRailDragPolicy.autoScrollDirection(
            location: CGPoint(x: 350, y: 180),
            initialLocation: CGPoint(x: 355, y: 180),
            viewport: viewport
        ) == nil)
    }

    @Test
    func edgeAutoScrollMovesOnlyOnePinnedSlotAtATime() {
        let order: [MemberID] = [31, 32, 33, 34]

        #expect(HomeFriendRailDragPolicy.movedOrder(
            order,
            draggedID: 32,
            direction: .forward
        ) == [31, 33, 32, 34])
        #expect(HomeFriendRailDragPolicy.movedOrder(
            order,
            draggedID: 33,
            direction: .backward
        ) == [31, 33, 32, 34])
    }

    @Test
    func edgeAutoScrollStopsAtPinnedBoundaries() {
        let order: [MemberID] = [31, 32, 33]

        #expect(HomeFriendRailDragPolicy.movedOrder(
            order,
            draggedID: 31,
            direction: .backward
        ) == order)
        #expect(HomeFriendRailDragPolicy.movedOrder(
            order,
            draggedID: 33,
            direction: .forward
        ) == order)
    }

    @Test
    func repeatedEdgeStepsCanCarryTheCardAcrossInitiallyOffscreenFriends() {
        var order: [MemberID] = [31, 32, 33, 34, 35]

        for _ in 0..<3 {
            order = HomeFriendRailDragPolicy.movedOrder(
                order,
                draggedID: 32,
                direction: .forward
            )
        }

        #expect(order == [31, 33, 34, 35, 32])
    }

    @Test
    func referenceSlotsCanRebaseAroundThePreviewAfterAutoScroll() {
        let frames = HomeFriendRailDragPolicy.referenceFrames(
            order: [31, 32, 33],
            draggedID: 31,
            sourceFrame: CGRect(x: 100, y: 40, width: 88, height: 160),
            spacing: 8
        )

        #expect(frames[31] == CGRect(x: 100, y: 40, width: 88, height: 160))
        #expect(frames[32] == CGRect(x: 196, y: 40, width: 88, height: 160))
        #expect(frames[33] == CGRect(x: 292, y: 40, width: 88, height: 160))
    }

    @Test
    func referenceSlotsCoverFriendsThatWereInitiallyOffscreen() {
        let order: [MemberID] = [31, 32, 33, 34, 35, 36]
        let frames = HomeFriendRailDragPolicy.referenceFrames(
            order: order,
            draggedID: 33,
            sourceFrame: CGRect(x: 100, y: 40, width: 88, height: 160),
            spacing: 8
        )

        #expect(frames.count == order.count)
        #expect(frames[31]?.minX == -92)
        #expect(frames[36]?.minX == 388)
    }
}
