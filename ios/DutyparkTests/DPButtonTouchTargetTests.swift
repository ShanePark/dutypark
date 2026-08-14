import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct DPButtonTouchTargetTests {
    @Test
    func buttonStylesMeetTheMinimumTouchTarget() {
        let buttons: [(name: String, view: AnyView)] = [
            ("primary text", AnyView(Button("I") {}.buttonStyle(DPPrimaryButtonStyle()))),
            ("primary icon", AnyView(Button {} label: { Image(systemName: "plus") }.buttonStyle(DPPrimaryButtonStyle()))),
            ("success text", AnyView(Button("I") {}.buttonStyle(DPSuccessButtonStyle()))),
            ("success icon", AnyView(Button {} label: { Image(systemName: "plus") }.buttonStyle(DPSuccessButtonStyle()))),
            ("destructive text", AnyView(Button("I") {}.buttonStyle(DPDestructiveButtonStyle()))),
            ("destructive icon", AnyView(Button {} label: { Image(systemName: "plus") }.buttonStyle(DPDestructiveButtonStyle()))),
            ("secondary text", AnyView(Button("I") {}.buttonStyle(DPSecondaryButtonStyle()))),
            ("secondary icon", AnyView(Button {} label: { Image(systemName: "plus") }.buttonStyle(DPSecondaryButtonStyle()))),
            ("outline text", AnyView(Button("I") {}.buttonStyle(DPOutlineButtonStyle()))),
            ("outline icon", AnyView(Button {} label: { Image(systemName: "plus") }.buttonStyle(DPOutlineButtonStyle())))
        ]

        for button in buttons {
            let size = fittingSize(of: button.view)
            expectMinimumTouchTarget(size, name: button.name)
        }
    }

    private func fittingSize<V: View>(of view: V) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: 320, height: 1_000)
        )
    }

    private func expectMinimumTouchTarget(_ size: CGSize, name: String) {
        #expect(
            size.width >= DPSize.minimumTouchTarget,
            "\(name) width was \(size.width)"
        )
        #expect(
            size.height >= DPSize.minimumTouchTarget,
            "\(name) height was \(size.height)"
        )
    }
}
