import SwiftUI
import Testing
@testable import Dutypark

@MainActor
struct DPModalPanelSizingTests {
    @Test
    func bodyHeightHugsShortContent() {
        let policy = makePolicy(dividerCount: 2)

        #expect(
            policy.bodyHeight(
                headerHeight: 80,
                bodyContentHeight: 120,
                footerHeight: 60
            ) == 120
        )
    }

    @Test
    func bodyHeightClampsLongContentToAvailableSpace() {
        let policy = makePolicy(dividerCount: 2)

        #expect(
            policy.bodyHeight(
                headerHeight: 80,
                bodyContentHeight: 800,
                footerHeight: 60
            ) == 358
        )
    }

    @Test
    func panelWithoutFooterUsesOneDivider() {
        let panel = DPModalPanel(
            maximumPanelHeight: 500,
            header: {
                Color.clear.frame(height: 80)
            },
            content: {
                Color.clear.frame(height: 800)
            }
        )

        #expect(panel.sizingPolicy.dividerCount == 1)
    }

    private func makePolicy(dividerCount: Int) -> DPModalPanelSizingPolicy {
        DPModalPanelSizingPolicy(
            maximumPanelHeight: 500,
            minimumBodyHeight: 44,
            dividerCount: dividerCount
        )
    }
}
