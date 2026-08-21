import CoreGraphics

/// The axis along which a pinned-friend list lays out its cards.
enum PinnedFriendReorderAxis {
    case horizontal
    case vertical
}

/// Live drag-reorder math shared by the pinned friend lists on Home and Social.
///
/// Drop-target frames are looked up by member ID rather than by position because
/// both lists render in lazy stacks: cards outside the viewport publish no frame,
/// so the target set is routinely a subset of the pinned order.
enum PinnedFriendReorder {
    static let overlapThreshold: CGFloat = 12

    static func reordered(
        _ originalOrder: [MemberID],
        draggedID: MemberID,
        previewFrame: CGRect,
        axis: PinnedFriendReorderAxis = .vertical,
        framesByID: [MemberID: CGRect]
    ) -> [MemberID] {
        guard let sourceIndex = originalOrder.firstIndex(of: draggedID),
              let sourceFrame = framesByID[draggedID] else {
            return originalOrder
        }

        var reordered = originalOrder
        reordered.remove(at: sourceIndex)

        let previewPosition = axis.position(of: previewFrame)
        let sourcePosition = axis.position(of: sourceFrame)

        if previewPosition > sourcePosition {
            let candidates = originalOrder.indices.dropFirst(sourceIndex + 1)
            guard let destinationIndex = candidates.last(where: { index in
                guard let frame = framesByID[originalOrder[index]] else { return false }
                return axis.trailingEdge(of: previewFrame) >= axis.leadingEdge(of: frame) + threshold(for: frame, axis: axis)
            }) else {
                reordered.insert(draggedID, at: sourceIndex)
                return reordered
            }
            reordered.insert(draggedID, at: destinationIndex)
        } else if previewPosition < sourcePosition {
            let candidates = originalOrder.indices.prefix(sourceIndex)
            guard let destinationIndex = candidates.first(where: { index in
                guard let frame = framesByID[originalOrder[index]] else { return false }
                return axis.leadingEdge(of: previewFrame) <= axis.trailingEdge(of: frame) - threshold(for: frame, axis: axis)
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

    private static func threshold(
        for frame: CGRect,
        axis: PinnedFriendReorderAxis
    ) -> CGFloat {
        min(overlapThreshold, axis.length(of: frame) * 0.2)
    }
}

private extension PinnedFriendReorderAxis {
    func position(of frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal: frame.midX
        case .vertical: frame.midY
        }
    }

    func leadingEdge(of frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal: frame.minX
        case .vertical: frame.minY
        }
    }

    func trailingEdge(of frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal: frame.maxX
        case .vertical: frame.maxY
        }
    }

    func length(of frame: CGRect) -> CGFloat {
        switch self {
        case .horizontal: frame.width
        case .vertical: frame.height
        }
    }
}
