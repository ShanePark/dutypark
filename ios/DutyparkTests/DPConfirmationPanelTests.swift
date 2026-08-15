import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct DPConfirmationPanelTests {
    @Test
    func panelUsesTheCompactWebConfirmationWidth() {
        let size = fittingSize(
            of: makePanel(),
            proposedWidth: 1_000
        )

        #expect(size.width == DPConfirmationPanel.maximumWidth)
        #expect(size.width >= DPConfirmationPanel.minimumWidth)
    }

    @Test
    func panelRemainsBoundedWithAccessibilityText() {
        let size = fittingSize(
            of: makePanel()
                .environment(\.dynamicTypeSize, .accessibility3),
            proposedWidth: 1_000
        )

        #expect(size.width == DPConfirmationPanel.maximumWidth)
        #expect(size.height <= 600)
    }

    private func makePanel() -> some View {
        DPConfirmationPanel(
            title: "Delete pattern",
            message: "Deleting the pattern also removes future duties. This action cannot be undone.",
            confirmTitle: "Delete",
            cancelTitle: "Cancel",
            isDestructive: true,
            maximumHeight: 600,
            cancel: {},
            confirm: {}
        )
    }

    private func fittingSize<V: View>(of view: V, proposedWidth: CGFloat) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: proposedWidth, height: 1_000)
        )
    }
}
