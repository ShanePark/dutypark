import SwiftUI

/// The tail of the "this month" callout: a slender pointer that climbs from the capsule to
/// the month label sitting in the navigation bar above it.
private struct DPThisMonthCalloutTail: Shape {
    nonisolated func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: CGPoint(x: rect.midX, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
            path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            path.closeSubpath()
        }
    }
}

/// The labelled speech bubble that returns a month-capsule header to the current month,
/// matching the web calendar's. Hosts lay it over the top of their body, below the 44pt
/// navigation bar, with `verticalOffset` and `tailCenter`, so the bar keeps its native height.
///
/// The month change owns its haptic, so the callout itself stays silent.
struct DPThisMonthCallout: View {
    let label: String
    let action: () -> Void

    // The month capsule is opaque down to the bar's lower edge, so a larger lift hides the tail.
    static let verticalOffset: CGFloat = -10

    // Aligning this point with the host's centre puts the tail under the month label,
    // whatever the label reads.
    nonisolated static let tailCenter: CGFloat = hitInsetX + tailInset + tailWidth / 2

    // The web calendar draws the tail near the leading edge of the bubble.
    private static let capsuleHeight: CGFloat = 20
    private nonisolated static let tailInset: CGFloat = 8
    private nonisolated static let tailWidth: CGFloat = 12
    private static let tailHeight: CGFloat = 6
    // Overlap that keeps the tail and the capsule reading as one shape.
    private static let tailOverlap: CGFloat = 2
    // The capsule is shorter than a touch target, so it takes what room the bar leaves
    // around itself; a taller hit area would only reach past the bar, which passes on
    // nothing it does not draw.
    private nonisolated static let hitInsetX: CGFloat = 6
    private static let hitInsetY: CGFloat = 6

    // Keep the callout's upper-left corner fixed while giving its label and hit area ten
    // percent more room toward the lower-right. A transform leaves the layout footprint
    // unchanged, so the tail stays where the host aligned it.
    private static let scale: CGFloat = 1.1

    var body: some View {
        Button(action: action) {
            HStack(spacing: 3) {
                Image(systemName: "arrow.uturn.backward")
                    .font(.system(size: 10, weight: .bold))
                Text(label)
                    .font(DPFont.bold(size: 11, relativeTo: .caption2))
                    .lineLimit(1)
            }
            .foregroundStyle(DPColor.textOnDark)
            .padding(.horizontal, 8)
            .frame(height: Self.capsuleHeight)
            .background(DPColor.accent, in: Capsule())
            .background(alignment: .topLeading) {
                DPThisMonthCalloutTail()
                    .fill(DPColor.accent)
                    .frame(width: Self.tailWidth, height: Self.tailHeight)
                    .offset(x: Self.tailInset, y: Self.tailOverlap - Self.tailHeight)
            }
            .compositingGroup()
            .shadow(color: DPColor.accent.opacity(0.35), radius: 4, x: 0, y: 2)
            .padding(.horizontal, Self.hitInsetX)
            .padding(.vertical, Self.hitInsetY)
            .contentShape(Rectangle())
        }
        .scaleEffect(Self.scale, anchor: .topLeading)
        .accessibilityLabel(label)
    }
}
