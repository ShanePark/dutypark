import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct DPContentStatesTests {
    @Test
    func errorStateRendersEveryCallSiteShape() {
        let shapes: [(name: String, view: AnyView)] = [
            ("title only", AnyView(DPErrorState(title: "Failed"))),
            ("title and message", AnyView(DPErrorState(title: "Failed", message: "Try again later"))),
            (
                "with retry",
                AnyView(
                    DPErrorState(
                        title: "Failed",
                        message: "Try again later",
                        retryTitle: "Retry",
                        retryAction: {}
                    )
                )
            )
        ]

        for shape in shapes {
            let size = fittingSize(of: shape.view)
            #expect(size.width > 0, "\(shape.name) width was \(size.width)")
            #expect(size.height > 0, "\(shape.name) height was \(size.height)")
        }
    }

    private func fittingSize<V: View>(of view: V) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: 320, height: 1_000)
        )
    }
}
