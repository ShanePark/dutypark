import CoreGraphics

nonisolated enum HomeFriendRailAutoScrollDirection: Int, Equatable, Sendable {
    case backward = -1
    case forward = 1
}

/// Pure layout rules for the Home pinned-friend rail while a card is held.
nonisolated enum HomeFriendRailDragPolicy {
    static let activationEdgeWidth: CGFloat = 56

    static func autoScrollDirection(
        location: CGPoint,
        initialLocation: CGPoint,
        viewport: CGRect,
        minimumMovement: CGFloat = 4
    ) -> HomeFriendRailAutoScrollDirection? {
        guard viewport.width > 0,
              viewport.minX...viewport.maxX ~= location.x else { return nil }

        let horizontalMovement = location.x - initialLocation.x
        let leadingDistance = location.x - viewport.minX
        let trailingDistance = viewport.maxX - location.x
        if leadingDistance <= activationEdgeWidth,
           leadingDistance <= trailingDistance,
           horizontalMovement <= -minimumMovement {
            return .backward
        }
        if trailingDistance <= activationEdgeWidth,
           horizontalMovement >= minimumMovement {
            return .forward
        }
        return nil
    }

    static func movedOrder(
        _ order: [MemberID],
        draggedID: MemberID,
        direction: HomeFriendRailAutoScrollDirection
    ) -> [MemberID] {
        guard let sourceIndex = order.firstIndex(of: draggedID) else { return order }
        let destinationIndex = sourceIndex + direction.rawValue
        guard order.indices.contains(destinationIndex) else { return order }

        var moved = order
        moved.remove(at: sourceIndex)
        moved.insert(draggedID, at: destinationIndex)
        return moved
    }

    /// Rebuilds every logical slot around the held preview. This keeps reordering
    /// available even when LazyHStack has not rendered the next offscreen card.
    static func referenceFrames(
        order: [MemberID],
        draggedID: MemberID,
        sourceFrame: CGRect,
        spacing: CGFloat
    ) -> [MemberID: CGRect] {
        guard let sourceIndex = order.firstIndex(of: draggedID) else { return [:] }
        let stride = sourceFrame.width + spacing

        return Dictionary(uniqueKeysWithValues: order.enumerated().map { index, memberID in
            let offset = CGFloat(index - sourceIndex) * stride
            return (
                memberID,
                CGRect(
                    x: sourceFrame.minX + offset,
                    y: sourceFrame.minY,
                    width: sourceFrame.width,
                    height: sourceFrame.height
                )
            )
        })
    }
}
