import CoreGraphics

/// Live drag-reorder math shared by the pinned friend lists on Home and Social.
///
/// Drop-target frames are looked up by member ID rather than by position because
/// both lists render in a `LazyVStack`: rows outside the viewport publish no
/// frame, so the target set is routinely a subset of the pinned order.
enum PinnedFriendReorder {
    static let overlapThreshold: CGFloat = 12

    static func reordered(
        _ originalOrder: [MemberID],
        draggedID: MemberID,
        previewFrame: CGRect,
        framesByID: [MemberID: CGRect]
    ) -> [MemberID] {
        guard let sourceIndex = originalOrder.firstIndex(of: draggedID),
              let sourceFrame = framesByID[draggedID] else {
            return originalOrder
        }

        var reordered = originalOrder
        reordered.remove(at: sourceIndex)

        if previewFrame.midY > sourceFrame.midY {
            let candidates = originalOrder.indices.dropFirst(sourceIndex + 1)
            guard let destinationIndex = candidates.last(where: { index in
                guard let frame = framesByID[originalOrder[index]] else { return false }
                return previewFrame.maxY >= frame.minY + threshold(for: frame)
            }) else {
                reordered.insert(draggedID, at: sourceIndex)
                return reordered
            }
            reordered.insert(draggedID, at: destinationIndex)
        } else if previewFrame.midY < sourceFrame.midY {
            let candidates = originalOrder.indices.prefix(sourceIndex)
            guard let destinationIndex = candidates.first(where: { index in
                guard let frame = framesByID[originalOrder[index]] else { return false }
                return previewFrame.minY <= frame.maxY - threshold(for: frame)
            }) else {
                reordered.insert(draggedID, at: sourceIndex)
                return reordered
            }
            reordered.insert(draggedID, at: destinationIndex)
        } else {
            reordered.insert(draggedID, at: sourceIndex)
        }

        return reordered
    }

    /// Later duplicates win, matching the drag code that reads the most recently
    /// published frame for a member.
    static func framesByID<Target>(
        _ targets: [Target],
        memberID: (Target) -> MemberID,
        frame: (Target) -> CGRect
    ) -> [MemberID: CGRect] {
        Dictionary(
            targets.map { (memberID($0), frame($0)) },
            uniquingKeysWith: { _, latest in latest }
        )
    }

    private static func threshold(for frame: CGRect) -> CGFloat {
        min(overlapThreshold, frame.height * 0.2)
    }
}
