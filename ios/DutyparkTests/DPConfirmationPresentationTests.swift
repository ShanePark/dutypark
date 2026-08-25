import SwiftUI
import Testing
import UIKit
@testable import Dutypark

struct DPConfirmationCopyTests {
    @Test
    func copyIsNonDestructiveUnlessRequested() {
        let copy = DPConfirmationCopy(
            title: "Title",
            message: "Message",
            confirmTitle: "Confirm",
            cancelTitle: "Cancel"
        )

        #expect(copy.isDestructive == false)
    }

    @Test
    func copyComparesEveryVisibleField() {
        let base = DPConfirmationCopy(
            title: "Title",
            message: "Message",
            confirmTitle: "Confirm",
            cancelTitle: "Cancel",
            isDestructive: true
        )

        #expect(
            base == DPConfirmationCopy(
                title: "Title",
                message: "Message",
                confirmTitle: "Confirm",
                cancelTitle: "Cancel",
                isDestructive: true
            )
        )
        #expect(
            base != DPConfirmationCopy(
                title: "Title",
                message: "Message",
                confirmTitle: "Confirm",
                cancelTitle: "Cancel",
                isDestructive: false
            )
        )
    }
}

struct DPConfirmationPresentationSourceTests {
    private func componentSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Components/DPConfirmationPresentation.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private func featureSource(_ path: String) throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: path)
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    @Test
    func theScaffoldKeepsTheOverlayWidthAndPanelWiringInOnePlace() throws {
        let source = try componentSource()

        #expect(source.contains("maximumContentWidth: DPConfirmationPanel.maximumWidth"))
        #expect(source.contains("DPConfirmationPanel("))
        #expect(source.contains("maximumHeight: availableSize.height"))
        #expect(source.contains("dismissHaptic: nil"))
        // The overlay owns the only `fullScreenCover` pairing: one for each shape.
        #expect(source.components(separatedBy: "DPModalOverlay(").count - 1 == 1)
        #expect(source.components(separatedBy: "fullScreenCover(").count - 1 == 2)
    }

    @Test
    func theScaffoldSupportsTheSpinnerAndDismissalOptionsCallSitesUse() throws {
        let source = try componentSource()

        #expect(source.contains("isPresented: Binding<Bool>"))
        #expect(source.contains("item: Binding<Item?>"))
        #expect(source.components(separatedBy: "isWorking: Bool = false").count - 1 == 2)
        #expect(source.components(separatedBy: "closeOnBackdrop: Bool = true").count - 1 == 2)
        #expect(source.components(separatedBy: "canDismiss: Bool = true").count - 1 == 2)
    }

    @Test
    func adoptedCallSitesNoLongerRepeatTheScaffold() throws {
        for path in [
            "Dutypark/Features/Attachments/AttachmentGallery.swift",
            "Dutypark/Features/Notifications/NotificationCenterView.swift"
        ] {
            let source = try featureSource(path)

            #expect(
                source.contains("maximumContentWidth: DPConfirmationPanel.maximumWidth") == false,
                "\(path) should present confirmations through dpConfirmation"
            )
            #expect(
                source.contains(".dpConfirmation("),
                "\(path) should present confirmations through dpConfirmation"
            )
        }

        // The team discard confirmations route through the shared scaffold.
        // `TeamAsyncConfirmationPanel` keeps its own overlay: it wraps the panel in extra
        // submission state, which the shared scaffold deliberately does not model.
        let teamSource = try featureSource("Dutypark/Features/Team/TeamManageView.swift")
        #expect(teamSource.contains("dpConfirmation("))
        #expect(teamSource.contains(".teamDiscardConfirmation(isPresented:"))
    }
}

@MainActor
struct DPConfirmationPresentationHostingTests {
    private struct Item: Identifiable {
        let id: Int
    }

    @Test
    func bothPresentationShapesStayInertWhileNothingIsPresented() {
        let boolShape = Color.clear
            .dpConfirmation(
                isPresented: .constant(false),
                copy: DPConfirmationCopy(
                    title: "Title",
                    message: "Message",
                    confirmTitle: "Confirm",
                    cancelTitle: "Cancel",
                    isDestructive: true
                ),
                isWorking: true,
                closeOnBackdrop: false,
                canDismiss: false,
                finishDismissal: {},
                cancel: { dismiss in dismiss() },
                confirm: { dismiss in dismiss() }
            )

        let itemShape = Color.clear
            .dpConfirmation(
                item: Binding<Item?>.constant(nil),
                copy: { item in
                    DPConfirmationCopy(
                        title: "Title \(item.id)",
                        message: "Message",
                        confirmTitle: "Confirm",
                        cancelTitle: "Cancel",
                        isDestructive: true
                    )
                },
                confirm: { _, dismiss in dismiss() }
            )

        #expect(fittingSize(of: boolShape).width.isFinite)
        #expect(fittingSize(of: itemShape).width.isFinite)
    }

    private func fittingSize<V: View>(of view: V) -> CGSize {
        UIHostingController(rootView: view).sizeThatFits(
            in: CGSize(width: 390, height: 844)
        )
    }
}
