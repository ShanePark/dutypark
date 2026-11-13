import SwiftUI

/// Where the month header puts its three slots inside a container of a given width.
///
/// The capsule is centred on the container and never shrinks. Each side gets the same room
/// beside it, whatever the other side holds, so the capsule stays put across screens whose
/// side items differ.
nonisolated struct DPMonthHeaderPlacement: Equatable, Sendable {
    /// Gap kept between a side item and the capsule.
    static let capsuleSpacing: CGFloat = 2

    let capsuleMinX: CGFloat
    let sideWidth: CGFloat
    let leadingWidth: CGFloat
    let trailingWidth: CGFloat

    init(
        containerWidth: CGFloat,
        capsuleWidth: CGFloat,
        leadingIdealWidth: CGFloat,
        trailingIdealWidth: CGFloat
    ) {
        capsuleMinX = (containerWidth - capsuleWidth) / 2
        sideWidth = max((containerWidth - capsuleWidth) / 2 - Self.capsuleSpacing, 0)
        leadingWidth = min(leadingIdealWidth, sideWidth)
        trailingWidth = min(trailingIdealWidth, sideWidth)
    }
}

/// The navigation-bar header of the month-capsule screens: a leading item, the month capsule
/// and a trailing item in one principal toolbar item.
///
/// As separate leading/principal/trailing items, the bar centred the capsule only when it fit
/// between the side items and otherwise slid it, so the capsule moved with the side items'
/// widths. Hosting all three here keeps the capsule on the bar's centre.
struct DPMonthHeaderBar<Leading: View, Center: View, Trailing: View>: View {
    private let leading: Leading
    private let center: Center
    private let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        DPMonthHeaderLayout {
            // Each slot is wrapped so an empty side still counts as one subview.
            ZStack(alignment: .leading) { leading }
            center
            ZStack(alignment: .trailing) { trailing }
        }
    }
}

private struct DPMonthHeaderLayout: Layout {
    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        guard subviews.count == 3 else { return .zero }
        let capsule = subviews[1].sizeThatFits(.unspecified)
        let leading = subviews[0].sizeThatFits(.unspecified)
        let trailing = subviews[2].sizeThatFits(.unspecified)
        let idealWidth = capsule.width
            + 2 * (max(leading.width, trailing.width) + DPMonthHeaderPlacement.capsuleSpacing)
        let width = proposal.width.flatMap { $0.isFinite ? $0 : nil } ?? idealWidth
        // Never narrower than the capsule: the bar ignores touches past the item's frame.
        return CGSize(width: max(width, capsule.width), height: capsule.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 3 else { return }
        let capsule = subviews[1].sizeThatFits(.unspecified)
        let placement = DPMonthHeaderPlacement(
            containerWidth: bounds.width,
            capsuleWidth: capsule.width,
            leadingIdealWidth: subviews[0].sizeThatFits(.unspecified).width,
            trailingIdealWidth: subviews[2].sizeThatFits(.unspecified).width
        )

        subviews[1].place(
            at: CGPoint(x: bounds.minX + placement.capsuleMinX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(capsule)
        )
        subviews[0].place(
            at: CGPoint(x: bounds.minX, y: bounds.midY),
            anchor: .leading,
            proposal: ProposedViewSize(width: placement.leadingWidth, height: bounds.height)
        )
        subviews[2].place(
            at: CGPoint(x: bounds.maxX, y: bounds.midY),
            anchor: .trailing,
            proposal: ProposedViewSize(width: placement.trailingWidth, height: bounds.height)
        )
    }
}
