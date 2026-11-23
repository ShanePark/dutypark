import SwiftUI
import UIKit

nonisolated enum DPCalendarZoomPolicy {
    static let maximumScale: CGFloat = 3

    static func scale(_ value: CGFloat) -> CGFloat {
        min(max(value, 1), maximumScale)
    }

    static func viewport(_ proposed: CGRect, size: CGSize) -> CGRect {
        let bounds = CGRect(origin: .zero, size: size)
        let visible = proposed.intersection(bounds)
        return visible.isEmpty || visible.isNull ? bounds : visible
    }

    static func offset(_ value: CGSize, scale: CGFloat, size: CGSize, visibleRect: CGRect) -> CGSize {
        guard scale > 1 else { return .zero }
        let visibleRect = viewport(visibleRect, size: size)
        return CGSize(
            width: min(max(value.width, visibleRect.maxX - size.width * scale), visibleRect.minX),
            height: min(max(value.height, visibleRect.maxY - size.height * scale), visibleRect.minY)
        )
    }

    static func pinchOffset(
        startScale: CGFloat, startOffset: CGSize, startLocation: CGPoint,
        location: CGPoint, scale: CGFloat, size: CGSize, visibleRect: CGRect
    ) -> CGSize {
        let contentPoint = CGPoint(
            x: (startLocation.x - startOffset.width) / startScale,
            y: (startLocation.y - startOffset.height) / startScale
        )
        return offset(
            CGSize(width: location.x - contentPoint.x * scale, height: location.y - contentPoint.y * scale),
            scale: scale, size: size, visibleRect: visibleRect
        )
    }
}

/// Keeps the original grid's layout and environment while UIKit tracks the pinch.
struct DPCalendarZoom<Content: View>: View {
    let resetID: AnyHashable
    @Binding var isActive: Bool
    @ViewBuilder let content: () -> Content
    @State private var scale: CGFloat = 1
    @State private var offset = CGSize.zero
    @State private var size = CGSize.zero
    @State private var visibleRect = CGRect.zero
    @State private var pinchStartScale: CGFloat = 1
    @State private var pinchStartOffset = CGSize.zero
    @State private var pinchStartLocation = CGPoint.zero
    @State private var panStartOffset = CGSize.zero
    @State private var isPinching = false

    var body: some View {
        content()
            .scaleEffect(scale, anchor: .topLeading)
            .offset(offset)
            .clipped()
            .contentShape(.interaction, Rectangle())
            .background {
                GeometryReader { proxy in
                    Color.clear
                        .onAppear { updateSize(proxy.size) }
                        .onChange(of: proxy.size) { _, next in updateSize(next) }
                }
            }
            .background(DPCalendarZoomBridge(
                resetID: resetID,
                isZoomed: { scale > 1 },
                onPinch: handlePinch,
                onPan: handlePan,
                onViewportChange: updateViewport
            ))
            .overlay(alignment: .topTrailing) {
                if scale > 1 {
                    Button {
                        reset()
                        DPHapticCenter.shared.emit(.selection)
                    } label: {
                        Label(CalendarLocalization.text("calendar.zoom.reset"), systemImage: "arrow.down.right.and.arrow.up.left")
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .padding(.horizontal, 12)
                            .frame(minHeight: DPSize.minimumTouchTarget)
                            .background(.regularMaterial, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("calendar.zoom.reset")
                    .padding(.top, max(visibleRect.minY, 0) + 6)
                    .padding(.trailing, 6)
                }
            }
            .onChange(of: resetID) { _, _ in reset() }
            .onDisappear { reset() }
    }

    private func reset() {
        scale = 1
        offset = .zero
        isPinching = false
        isActive = false
    }

    private func updateSize(_ next: CGSize) {
        guard next.width > 0, next.height > 0, next.width.isFinite, next.height.isFinite else { return }
        size = next
        // Lazy calendar cells can be remeasured during a pan without changing the month.
        updateViewport(visibleRect)
    }

    private func updateViewport(_ next: CGRect) {
        visibleRect = DPCalendarZoomPolicy.viewport(next, size: size)
        offset = DPCalendarZoomPolicy.offset(offset, scale: scale, size: size, visibleRect: visibleRect)
    }

    private func handlePinch(_ phase: UIGestureRecognizer.State, _ magnification: CGFloat, _ location: CGPoint, _ viewport: CGRect) {
        updateViewport(viewport)
        if phase == .began {
            pinchStartScale = scale
            pinchStartOffset = offset
            pinchStartLocation = location
            isPinching = true
            isActive = true
        }
        if phase == .began || phase == .changed {
            scale = DPCalendarZoomPolicy.scale(pinchStartScale * magnification)
            offset = DPCalendarZoomPolicy.pinchOffset(
                startScale: pinchStartScale, startOffset: pinchStartOffset, startLocation: pinchStartLocation,
                location: location, scale: scale, size: size, visibleRect: visibleRect
            )
        }
        if phase == .ended || phase == .cancelled || phase == .failed {
            isPinching = false
            isActive = scale > 1
        }
    }

    private func handlePan(_ phase: UIGestureRecognizer.State, _ translation: CGPoint, _ viewport: CGRect) {
        guard !isPinching else { return }
        updateViewport(viewport)
        if phase == .began { panStartOffset = offset }
        if phase == .began || phase == .changed {
            offset = DPCalendarZoomPolicy.offset(
                CGSize(width: panStartOffset.width + translation.x, height: panStartOffset.height + translation.y),
                scale: scale, size: size, visibleRect: visibleRect
            )
        }
    }
}

private struct DPCalendarZoomBridge: UIViewRepresentable {
    let resetID: AnyHashable
    let isZoomed: () -> Bool
    let onPinch: (UIGestureRecognizer.State, CGFloat, CGPoint, CGRect) -> Void
    let onPan: (UIGestureRecognizer.State, CGPoint, CGRect) -> Void
    let onViewportChange: (CGRect) -> Void

    func makeUIView(context: Context) -> DPCalendarZoomAnchor {
        let anchor = DPCalendarZoomAnchor(coordinator: context.coordinator)
        anchor.isUserInteractionEnabled = false
        context.coordinator.anchor = anchor
        return anchor
    }

    func updateUIView(_ uiView: DPCalendarZoomAnchor, context: Context) {
        context.coordinator.isZoomed = isZoomed
        context.coordinator.onPinch = onPinch
        context.coordinator.onPan = onPan
        context.coordinator.onViewportChange = onViewportChange
        context.coordinator.resetIfNeeded(for: resetID)
        uiView.attach()
    }

    func makeCoordinator() -> DPCalendarZoomCoordinator { DPCalendarZoomCoordinator() }
}

private final class DPCalendarZoomAnchor: UIView {
    private let coordinator: DPCalendarZoomCoordinator

    init(coordinator: DPCalendarZoomCoordinator) {
        self.coordinator = coordinator
        super.init(frame: .zero)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        if window == nil { coordinator.detach() }
        else { attach() }
    }

    func attach() {
        var candidate = superview
        while let view = candidate {
            if let scrollView = view as? UIScrollView {
                coordinator.attach(to: scrollView)
                return
            }
            candidate = view.superview
        }
    }
}

@MainActor
final class DPCalendarZoomCoordinator: NSObject, UIGestureRecognizerDelegate {
    weak var anchor: UIView?
    private weak var scrollView: UIScrollView?
    private var scrollObservation: NSKeyValueObservation?
    private var restoresScrollPan = false
    private var isPinching = false
    private var isPanning = false
    private var isResetting = false
    private var resetID: AnyHashable?
    var isZoomed: () -> Bool = { false }
    var onPinch: (UIGestureRecognizer.State, CGFloat, CGPoint, CGRect) -> Void = { _, _, _, _ in }
    var onPan: (UIGestureRecognizer.State, CGPoint, CGRect) -> Void = { _, _, _ in }
    var onViewportChange: (CGRect) -> Void = { _ in }

    lazy var pinch: UIPinchGestureRecognizer = {
        let gesture = UIPinchGestureRecognizer(target: self, action: #selector(pinched(_:)))
        gesture.delegate = self
        return gesture
    }()

    lazy var pan: UIPanGestureRecognizer = {
        let gesture = UIPanGestureRecognizer(target: self, action: #selector(panned(_:)))
        gesture.maximumNumberOfTouches = 1
        gesture.delegate = self
        return gesture
    }()

    func attach(to scrollView: UIScrollView) {
        guard self.scrollView !== scrollView else { return }
        detach()
        self.scrollView = scrollView
        scrollView.addGestureRecognizer(pinch)
        scrollView.addGestureRecognizer(pan)
        scrollView.panGestureRecognizer.require(toFail: pan)
        scrollObservation = scrollView.observe(\.contentOffset) { [weak self] _, _ in
            DispatchQueue.main.async {
                guard let self, self.isZoomed() else { return }
                self.onViewportChange(self.viewport)
            }
        }
    }

    func detach() {
        isPinching = false
        isPanning = false
        restoreScrollPan()
        scrollObservation = nil
        pinch.view?.removeGestureRecognizer(pinch)
        pan.view?.removeGestureRecognizer(pan)
        scrollView = nil
    }

    func resetIfNeeded(for id: AnyHashable) {
        defer { resetID = id }
        guard let resetID, resetID != id else { return }
        isResetting = true
        pinch.isEnabled = false
        pan.isEnabled = false
        isPinching = false
        isPanning = false
        restoreScrollPan()
        pinch.isEnabled = true
        pan.isEnabled = true
        isResetting = false
    }

    private var viewport: CGRect {
        guard let anchor, let scrollView else { return .zero }
        let visible = anchor.bounds.intersection(anchor.convert(scrollView.bounds, from: scrollView))
        return visible.isNull ? anchor.bounds : visible
    }

    @objc private func pinched(_ gesture: UIPinchGestureRecognizer) {
        handlePinch(state: gesture.state, scale: gesture.scale, location: gesture.location(in: anchor))
    }

    func handlePinch(state: UIGestureRecognizer.State, scale: CGFloat, location: CGPoint) {
        guard !isResetting else { return }
        if state == .began {
            isPinching = true
            suppressScrollPan()
        }
        onPinch(state, scale, location, viewport)
        if state == .ended || state == .cancelled || state == .failed {
            isPinching = false
            restoreScrollPan()
        }
    }

    @objc private func panned(_ gesture: UIPanGestureRecognizer) {
        handlePan(state: gesture.state, translation: gesture.translation(in: gesture.view))
    }

    func handlePan(state: UIGestureRecognizer.State, translation: CGPoint) {
        guard !isResetting else { return }
        if state == .began {
            isPanning = true
            suppressScrollPan()
        }
        if !isPinching { onPan(state, translation, viewport) }
        if state == .ended || state == .cancelled || state == .failed {
            isPanning = false
            restoreScrollPan()
        }
    }

    private func suppressScrollPan() {
        guard let scrollView, scrollView.panGestureRecognizer.isEnabled else { return }
        restoresScrollPan = true
        scrollView.panGestureRecognizer.isEnabled = false
    }

    private func restoreScrollPan() {
        guard !isPinching, !isPanning, restoresScrollPan else { return }
        restoresScrollPan = false
        scrollView?.panGestureRecognizer.isEnabled = true
    }

    func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        guard let anchor, anchor.bounds.contains(gestureRecognizer.location(in: anchor)) else { return false }
        return gestureRecognizer === pinch || (isZoomed() && !isPinching)
    }

    func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool {
        // SwiftUI buttons and the enclosing scroll view may claim their touches
        // before the two-finger pinch begins. The pinch takes over scrolling in .began.
        gestureRecognizer === pinch || otherGestureRecognizer === pinch
    }
}
