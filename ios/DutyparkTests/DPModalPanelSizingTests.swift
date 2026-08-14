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
    func panelWithoutFooterAccountsForOneDivider() {
        let policy = makePolicy(dividerCount: 1)

        #expect(
            policy.bodyHeight(
                headerHeight: 80,
                bodyContentHeight: 800,
                footerHeight: 0
            ) == 419
        )
    }

    private func makePolicy(dividerCount: Int) -> DPModalPanelSizingPolicy {
        DPModalPanelSizingPolicy(
            maximumPanelHeight: 500,
            minimumBodyHeight: 44,
            dividerCount: dividerCount
        )
    }
}
