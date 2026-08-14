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
    private let hasFooter: Bool
    private let header: Header
    private let content: PanelContent
    private let footer: Footer

    @State private var headerHeight: CGFloat = 0
    @State private var bodyContentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0

    init(
        maximumPanelHeight: CGFloat,
        minimumBodyHeight: CGFloat = DPSize.minimumTouchTarget,
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> PanelContent,
        @ViewBuilder footer: () -> Footer
    ) {
        self.maximumPanelHeight = maximumPanelHeight
        self.minimumBodyHeight = minimumBodyHeight
        self.hasFooter = Footer.self != EmptyView.self
        self.header = header()
        self.content = content()
        self.footer = footer()
    }

    private var sizingPolicy: DPModalPanelSizingPolicy {
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

            ScrollView {
                content
                    .background { heightReader(DPModalPanelBodyHeightPreferenceKey.self) }
            }
            .scrollDismissesKeyboard(.interactively)
            .scrollBounceBehavior(.basedOnSize)
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
        @ViewBuilder header: () -> Header,
        @ViewBuilder content: () -> PanelContent
    ) {
        self.init(
            maximumPanelHeight: maximumPanelHeight,
            minimumBodyHeight: minimumBodyHeight,
            header: header,
            content: content,
            footer: { EmptyView() }
        )
    }
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
