import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct DPHelpAffordanceTests {
    @Test
    func helpAffordanceIsNamedByTheInformationGlyph() {
        #expect(DPHelpChrome.systemImage == "info.circle")
    }

    @Test
    func helpButtonMeetsTheMinimumTouchTarget() {
        let size = fittingSize(of: DPHelpButton(label: "Help") {}, maximumHeight: 1_000)

        #expect(size.width >= DPSize.minimumTouchTarget, "width was \(size.width)")
        #expect(size.height >= DPSize.minimumTouchTarget, "height was \(size.height)")
    }

    @Test
    func everyHelpPanelKeepsTheSharedHeightCap() {
        let availableHeight: CGFloat = 900
        let cap = min(
            availableHeight * DPHelpChrome.maximumPanelHeightRatio,
            DPHelpChrome.maximumPanelHeight
        )
        let panels: [(name: String, view: AnyView)] = [
            ("todo", AnyView(TodoHelpModal(maximumHeight: availableHeight, dismiss: {}))),
            ("social", AnyView(SocialHelpModal(maximumHeight: availableHeight, dismiss: {})))
        ]

        for panel in panels {
            let size = fittingSize(of: panel.view, maximumHeight: availableHeight)
            #expect(size.height <= cap + 1, "\(panel.name) panel was \(size.height)")
        }
    }

    private func fittingSize<V: View>(of view: V, maximumHeight: CGFloat) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: 375, height: maximumHeight)
        )
    }
}
