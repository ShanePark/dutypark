import SwiftUI

struct DPModalPanelSizingPolicy {
    let maximumPanelHeight: CGFloat
    let minimumBodyHeight: CGFloat
    let dividerCount: Int

    func bodyHeight(
        headerHeight: CGFloat,
        bodyContentHeight: CGFloat,
        footerHeight: CGFloat
    ) -> CGFloat {
        let dividerAllowance = DPChrome.borderWidth * CGFloat(dividerCount)
        let availableBodyHeight = max(
            minimumBodyHeight,
            maximumPanelHeight - headerHeight - footerHeight - dividerAllowance
        )
        return min(max(bodyContentHeight, minimumBodyHeight), availableBodyHeight)
    }
}

/// Content panel for `DPModalOverlay` that hugs its content height,
/// caps at `maximumPanelHeight`, and scrolls the body when content exceeds the cap.
///
/// A plain `.frame(maxHeight:)` cannot do this: with only a max constraint,
/// a frame greedily stretches to the max whenever the proposal is larger than
/// its content, which left panels with dead space below their footers.
struct DPModalPanel<Header: View, PanelContent: View, Footer: View>: View {
    private let maximumPanelHeight: CGFloat
    private let minimumBodyHeight: CGFloat
    private let scrollTarget: AnyHashable?
    private let hasFooter: Bool
    private let header: Header
    private let content: PanelContent
    private let footer: Footer

    @State private var headerHeight: CGFloat = 0
    @State private var bodyContentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    /// - Parameter scrollTarget: identifier of the body element that must stay visible,
    ///   typically the focused field. The body scrolls to the matching `.id(_:)` whenever
    ///   this changes, so the keyboard cannot hide the field the user is editing.
    init(
        maximumPanelHeight: CGFloat,
        minimumBodyHeight: CGFloat = DPSize.minimumTouchTarget,
        scrollTarget: AnyHashable? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> PanelContent,
        @ViewBuilder footer: () -> Footer
    ) {
        self.maximumPanelHeight = maximumPanelHeight
        self.minimumBodyHeight = minimumBodyHeight
        self.scrollTarget = scrollTarget
        self.hasFooter = Footer.self != EmptyView.self
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    var sizingPolicy: DPModalPanelSizingPolicy {
        DPModalPanelSizingPolicy(
            maximumPanelHeight: maximumPanelHeight,
            minimumBodyHeight: minimumBodyHeight,
            dividerCount: hasFooter ? 2 : 1
        )
    }

    private var clampedBodyHeight: CGFloat {
        sizingPolicy.bodyHeight(
            headerHeight: headerHeight,
            bodyContentHeight: bodyContentHeight,
            footerHeight: footerHeight
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            header
                .background { heightReader(DPModalPanelHeaderHeightPreferenceKey.self) }

            Divider().overlay(DPColor.borderPrimary)

            ScrollViewReader { proxy in
                ScrollView {
                    content
                        .background { heightReader(DPModalPanelBodyHeightPreferenceKey.self) }
                }
                .scrollDismissesKeyboard(.interactively)
                .scrollBounceBehavior(.basedOnSize)
                .task(id: scrollTarget) {
                    await revealScrollTarget(using: proxy)
                }
            }
            .frame(height: clampedBodyHeight)

            if hasFooter {
                Divider().overlay(DPColor.borderPrimary)

                footer
                    .background { heightReader(DPModalPanelFooterHeightPreferenceKey.self) }
            }
        }
        .dpKeyboardDismissToolbar()
        .onPreferenceChange(DPModalPanelHeaderHeightPreferenceKey.self) { headerHeight = $0 }
        .onPreferenceChange(DPModalPanelBodyHeightPreferenceKey.self) { bodyContentHeight = $0 }
        .onPreferenceChange(DPModalPanelFooterHeightPreferenceKey.self) { footerHeight = $0 }
    }

    private func revealScrollTarget(using proxy: ScrollViewProxy) async {
        guard let scrollTarget else { return }

        scroll(proxy, to: scrollTarget)
        // Focusing a field also raises the keyboard, which shrinks the body underneath the
        // scroll that just ran. Repeat once the keyboard animation settles so the field
        // ends up inside the smaller body instead of below it.
        try? await Task.sleep(for: .milliseconds(DPModalPanelLayout.keyboardSettlingDelayMilliseconds))
        scroll(proxy, to: scrollTarget)
    }

    private func scroll(_ proxy: ScrollViewProxy, to target: AnyHashable) {
        withAnimation(.easeOut(duration: 0.2)) {
            proxy.scrollTo(target, anchor: .top)
        }
    }

    private func heightReader<Key: PreferenceKey>(_ key: Key.Type) -> some View where Key.Value == CGFloat {
        GeometryReader { proxy in
            Color.clear.preference(key: key, value: proxy.size.height)
        }
    }
}

extension DPModalPanel where Footer == EmptyView {
    init(
        maximumPanelHeight: CGFloat,
        minimumBodyHeight: CGFloat = DPSize.minimumTouchTarget,
        scrollTarget: AnyHashable? = nil,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> PanelContent
    ) {
        self.init(
            maximumPanelHeight: maximumPanelHeight,
            minimumBodyHeight: minimumBodyHeight,
            scrollTarget: scrollTarget,
            header: header,
            content: content,
            footer: { EmptyView() }
        )
    }
}

enum DPModalPanelLayout {
    /// Slightly longer than the system keyboard's presentation animation.
    static let keyboardSettlingDelayMilliseconds = 320
}

private struct DPModalPanelHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct DPModalPanelBodyHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}

private struct DPModalPanelFooterHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = max(value, nextValue()) }
}
