import SwiftUI

enum DPMonthCapsuleMetrics {
    static let height: CGFloat = 44

    /// Each arrow is a square as tall as the capsule. A narrower segment pushes the circle
    /// off-centre from the capsule's rounded end.
    static let segmentSize: CGFloat = height

    /// Leaves an even 6pt inset between the circle and the capsule's edge.
    static let circleSize: CGFloat = 32
    static let pressedScale: CGFloat = 0.92
    static let arrowIconSize: CGFloat = 16

    /// The navigation-bar headers share their row with leading and trailing items.
    static let compactMonthFontSize: CGFloat = 16
    static let monthFontSize: CGFloat = 18
    static let monthChevronSize: CGFloat = 10
    static let monthSpacing: CGFloat = 2
    static let monthLeadingPadding: CGFloat = 8
    static let monthTrailingPadding: CGFloat = 6
}

struct DPMonthCapsuleArrow {
    let label: String
    let identifier: String
    let action: () -> Void
}

/// Previous month, year-month and next month joined into one capsule, matching the web
/// calendar's month navigator. Touch never hovers, so the arrows paint their circles at rest:
/// the circles are what separate the segments.
///
/// The month change itself owns its haptic, so the arrows stay silent on press; the
/// year-month action carries whatever feedback its screen already gives.
struct DPMonthCapsule: View {
    let yearMonth: String
    var monthFontSize: CGFloat = DPMonthCapsuleMetrics.monthFontSize
    let monthAccessibilityLabel: String
    let monthIdentifier: String
    let previous: DPMonthCapsuleArrow
    let next: DPMonthCapsuleArrow
    let onMonthTap: () -> Void

    @State private var isMonthPressed = false

    var body: some View {
        HStack(spacing: 0) {
            arrow(previous, systemImage: "chevron.left")
            monthButton
            arrow(next, systemImage: "chevron.right")
        }
        .frame(height: DPMonthCapsuleMetrics.height)
        // The navigation bar proposes less than the capsule needs on a 375pt screen and
        // would truncate the year-month; keep the capsule at its natural width instead.
        .fixedSize(horizontal: true, vertical: false)
        .background {
            Capsule().fill(isMonthPressed ? DPColor.accentSoft : DPColor.backgroundCard)
                .shadow(color: .black.opacity(0.05), radius: 1, x: 0, y: 1)
                .shadow(color: .black.opacity(0.04), radius: 4, x: 0, y: 2)
        }
        .overlay {
            // Drawn just outside the edge, like the web's ring, so the circles keep their inset.
            Capsule()
                .inset(by: -DPChrome.borderWidth / 2)
                .stroke(isMonthPressed ? DPColor.accentBorder : DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
                .allowsHitTesting(false)
        }
        .animation(.easeOut(duration: 0.18), value: isMonthPressed)
    }

    private func arrow(_ arrow: DPMonthCapsuleArrow, systemImage: String) -> some View {
        Button(action: arrow.action) {
            Image(systemName: systemImage)
                .font(.system(size: DPMonthCapsuleMetrics.arrowIconSize, weight: .semibold))
        }
        .buttonStyle(DPMonthCapsuleArrowStyle())
        .accessibilityLabel(arrow.label)
        .accessibilityIdentifier(arrow.identifier)
    }

    private var monthButton: some View {
        Button(action: onMonthTap) {
            HStack(spacing: DPMonthCapsuleMetrics.monthSpacing) {
                // The app font has no tabular figures, so `monospacedDigit()` does nothing and
                // the capsule would resize with every month. Reserve the width of the same
                // label drawn with its widest digit instead.
                Text(verbatim: Self.widestDigitTemplate(for: yearMonth))
                    .hidden()
                    .overlay { Text(verbatim: yearMonth) }
                    .font(DPFont.bold(size: monthFontSize, relativeTo: .headline))
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Image(systemName: "chevron.down")
                    .font(.system(size: DPMonthCapsuleMetrics.monthChevronSize, weight: .bold))
                    .foregroundStyle(isMonthPressed ? DPColor.accent : DPColor.textMuted)
            }
            .padding(.leading, DPMonthCapsuleMetrics.monthLeadingPadding)
            .padding(.trailing, DPMonthCapsuleMetrics.monthTrailingPadding)
            .frame(maxHeight: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(DPMonthCapsuleMonthStyle(isPressed: $isMonthPressed))
        .accessibilityLabel(monthAccessibilityLabel)
        .accessibilityValue(yearMonth)
        .accessibilityIdentifier(monthIdentifier)
    }

    /// "0" is the widest digit in the app font.
    nonisolated static func widestDigitTemplate(for text: String) -> String {
        String(text.map { $0.isASCII && $0.isNumber ? "0" : $0 })
    }
}

private struct DPMonthCapsuleArrowStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DPColor.accent)
            .background {
                Circle()
                    .fill(configuration.isPressed ? DPColor.accentSoftHover : DPColor.accentSoft)
                    .frame(width: DPMonthCapsuleMetrics.circleSize, height: DPMonthCapsuleMetrics.circleSize)
                    .scaleEffect(configuration.isPressed ? DPMonthCapsuleMetrics.pressedScale : 1)
            }
            .frame(width: DPMonthCapsuleMetrics.segmentSize, height: DPMonthCapsuleMetrics.segmentSize)
            .contentShape(Rectangle())
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
            .animation(.easeOut(duration: 0.18), value: configuration.isPressed)
    }
}

/// The pressed year-month tints the whole capsule, which the button's own style cannot reach,
/// so the style hands its pressed state up to the capsule.
private struct DPMonthCapsuleMonthStyle: ButtonStyle {
    @Binding var isPressed: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
    }
}
