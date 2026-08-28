import SwiftUI

nonisolated enum DPMonthArrowDirection {
    case previous
    case next

    var systemImage: String {
        switch self {
        case .previous: "chevron.left"
        case .next: "chevron.right"
        }
    }
}

enum DPMonthArrowMetrics {
    /// Painted circle. Smaller than a touch target on purpose: the arrows share a 44pt
    /// header row with the year-month label and would crowd it at full size.
    static let controlSize: CGFloat = 34

    /// Slot the control occupies. The transparent remainder around the circle still
    /// answers to touch, so the arrow keeps the full `DPSize.minimumTouchTarget` height.
    static let slotWidth: CGFloat = 42

    static let iconSize: CGFloat = 16
}

/// Chrome for the month step arrows.
///
/// The surface is painted at all times rather than on press or hover alone, and the slot
/// around it carries the content shape, so the whole target is both visible and tappable.
/// The accent wash carries the shape on its own; a border only made it read as a form field.
struct DPMonthArrowButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled

    var slotWidth: CGFloat = DPMonthArrowMetrics.slotWidth

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(DPColor.accent)
            .frame(width: DPMonthArrowMetrics.controlSize, height: DPMonthArrowMetrics.controlSize)
            .background(Circle().fill(configuration.isPressed ? DPColor.accentSoftHover : DPColor.accentSoft))
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
            .frame(width: slotWidth, height: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
    }
}

/// Previous/next month arrow shared by the calendar headers.
///
/// These used to be a bare chevron inside a transparent frame. Nothing showed where the
/// button was — the hover surface the web shares with them never applies on touch — and
/// because the frame carried no content shape, only the glyph itself answered to a tap.
///
/// The month change itself owns its haptic, so the arrow stays silent on press.
struct DPMonthArrowButton: View {
    let direction: DPMonthArrowDirection
    let label: String
    let identifier: String
    var slotWidth: CGFloat = DPMonthArrowMetrics.slotWidth
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: direction.systemImage)
                .font(.system(size: DPMonthArrowMetrics.iconSize, weight: .bold))
        }
        .buttonStyle(DPMonthArrowButtonStyle(slotWidth: slotWidth))
        .accessibilityLabel(label)
        .accessibilityIdentifier(identifier)
    }
}
