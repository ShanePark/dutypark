import SwiftUI

/// Timing, geometry and rules for the "hold to reorder" affordance shared by every
/// drag surface: the ring that fills while the press is held, and the highlight the
/// card wears once the press has turned into a drag.
///
/// The ring only helps if it empties exactly when the card lifts, so the press
/// threshold lives here and the surfaces read it from here rather than declaring
/// their own copy that can drift away from the animation.
nonisolated enum DPDragActivation {
    /// How long a card has to be held before it lifts.
    static let pressDuration: TimeInterval = 0.35

    /// How far the finger may drift before the press is abandoned. Matches the
    /// recognizer's own `allowableMovement`, so the ring never keeps filling for a
    /// press the recognizer has already given up on.
    static let maximumPressMovement: CGFloat = 10

    /// The ring stays invisible for this long after touch down, so a tap and the
    /// first moments of a scroll never flash it. The fill underneath still starts
    /// at touch down, which is why the arc is already part-way round when it
    /// appears — it shows the time actually left, not the time since it faded in.
    static let ringAppearDelay: TimeInterval = 0.1
    static let ringFadeDuration: TimeInterval = 0.12
    static let ringDiameter: CGFloat = 38
    static let ringLineWidth: CGFloat = 3
    static let ringRestingScale: CGFloat = 0.7

    /// The lifted card, once the press has turned into a drag.
    static let liftScale: CGFloat = 1.05
    static let liftRingWidth: CGFloat = 2.5
    static let liftGlowRadius: CGFloat = 10
    static let liftGlowOpacity: Double = 0.3
    static let liftShadowRadius: CGFloat = 16
    static let liftShadowOpacity: Double = 0.22
    static let liftShadowOffsetY: CGFloat = 8

    /// The gap a lifted card leaves behind.
    static let sourceSlotFillOpacity: Double = 0.06
    static let sourceSlotStrokeOpacity: Double = 0.45
    static let sourceSlotStrokeWidth: CGFloat = 2
    static let sourceSlotDash: [CGFloat] = [6, 4]

    /// How much of the ring is already filled at the moment it fades in.
    static var progressWhenRingAppears: Double {
        ringAppearDelay / pressDuration
    }
}

/// The gauge that fills while a reorder press is held, so the hold has a visible end
/// instead of leaving the finger to guess how much longer to wait.
struct DPPressProgressRing: View {
    let progress: Double
    let tint: Color

    var body: some View {
        ZStack {
            Circle()
                .fill(DPColor.backgroundCard)
                .shadow(color: .black.opacity(0.15), radius: 4, y: 2)

            Circle()
                .strokeBorder(tint.opacity(0.2), lineWidth: DPDragActivation.ringLineWidth)

            Circle()
                .inset(by: DPDragActivation.ringLineWidth / 2)
                .trim(from: 0, to: progress)
                .stroke(
                    tint,
                    style: StrokeStyle(lineWidth: DPDragActivation.ringLineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
        .frame(width: DPDragActivation.ringDiameter, height: DPDragActivation.ringDiameter)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Draws `DPPressProgressRing` for a press the surface is already tracking.
///
/// Deliberately gesture-free: the ring is driven by the reorder recognizer's own
/// touch-down report. An extra `DragGesture` layered on the card to detect the
/// press competes with the enclosing scroll view, which breaks vertical scrolling
/// from a card and the reorder drag itself.
private struct DPPressProgressModifier: ViewModifier {
    let isPressing: Bool
    let isDragging: Bool
    let tint: Color

    @State private var progress: Double = 0
    @State private var ringOpacity: Double = 0
    @State private var isCountingDown = false

    func body(content: Content) -> some View {
        content
            .overlay {
                // Kept in the tree rather than inserted on press: the fill is an
                // animation of `progress`, and a view inserted after that animation
                // started would snap straight to a full ring.
                DPPressProgressRing(progress: progress, tint: tint)
                    .scaleEffect(
                        DPDragActivation.ringRestingScale
                            + (1 - DPDragActivation.ringRestingScale) * ringOpacity
                    )
                    .opacity(ringOpacity)
            }
            .onChange(of: isPressing) { _, isPressing in
                if isPressing { beginPress() } else { endPress() }
            }
            .onChange(of: isDragging) { _, isDragging in
                if isDragging { endPress() }
            }
    }

    private func beginPress() {
        guard !isDragging else { return }
        isCountingDown = true
        progress = 0
        ringOpacity = 0

        withAnimation(
            .easeOut(duration: DPDragActivation.ringFadeDuration)
                .delay(DPDragActivation.ringAppearDelay)
        ) {
            ringOpacity = 1
        }

        withAnimation(
            .linear(duration: DPDragActivation.pressDuration),
            completionCriteria: .logicallyComplete
        ) {
            progress = 1
        } completion: {
            // The card has lifted by now, so the ring has said all it can say.
            endPress()
        }
    }

    private func endPress() {
        guard isCountingDown else { return }
        isCountingDown = false
        withAnimation(.easeOut(duration: DPDragActivation.ringFadeDuration)) {
            ringOpacity = 0
            progress = 0
        }
    }
}

extension View {
    /// Fills a ring over this item while a reorder press is held on it, and clears
    /// it as soon as the press is released, drifts away, or turns into a drag.
    ///
    /// - Parameters:
    ///   - isPressing: whether the finger is currently down on this item, as
    ///     reported by the surface's own reorder recognizer.
    ///   - isDragging: whether this item is the one currently held.
    ///   - tint: the surface's own accent, so the ring matches what it is filling towards.
    func dpPressProgress(
        isPressing: Bool,
        isDragging: Bool,
        tint: Color
    ) -> some View {
        modifier(DPPressProgressModifier(isPressing: isPressing, isDragging: isDragging, tint: tint))
    }

    /// The card under the finger once it is actually draggable: lifted, ringed in
    /// the surface's tint and raised off a deeper shadow, so "you can move this now"
    /// reads without having to notice that the card moved.
    func dpDragLift(tint: Color, cornerRadius: CGFloat) -> some View {
        overlay {
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(tint, lineWidth: DPDragActivation.liftRingWidth)
                .allowsHitTesting(false)
        }
        .shadow(
            color: tint.opacity(DPDragActivation.liftGlowOpacity),
            radius: DPDragActivation.liftGlowRadius
        )
        .shadow(
            color: .black.opacity(DPDragActivation.liftShadowOpacity),
            radius: DPDragActivation.liftShadowRadius,
            y: DPDragActivation.liftShadowOffsetY
        )
        .scaleEffect(DPDragActivation.liftScale)
    }

    /// The gap a lifted card leaves behind. A dashed slot instead of an empty hole
    /// keeps the origin readable while the neighbours shift around it.
    func dpDragSourceSlot(isLifted: Bool, tint: Color, cornerRadius: CGFloat) -> some View {
        opacity(isLifted ? 0 : 1)
            .overlay {
                if isLifted {
                    RoundedRectangle(cornerRadius: cornerRadius)
                        .fill(tint.opacity(DPDragActivation.sourceSlotFillOpacity))
                        .overlay {
                            RoundedRectangle(cornerRadius: cornerRadius)
                                .stroke(
                                    tint.opacity(DPDragActivation.sourceSlotStrokeOpacity),
                                    style: StrokeStyle(
                                        lineWidth: DPDragActivation.sourceSlotStrokeWidth,
                                        dash: DPDragActivation.sourceSlotDash
                                    )
                                )
                        }
                        .allowsHitTesting(false)
                        .accessibilityHidden(true)
                        .transition(.opacity)
                }
            }
    }
}
