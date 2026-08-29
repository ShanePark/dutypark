import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct SharedComponentTests {
    @Test
    func inputChromeMeetsTheMinimumTouchTargetInEveryState() {
        let states = [
            (focused: false, invalid: false, disabled: false),
            (focused: true, invalid: false, disabled: false),
            (focused: false, invalid: true, disabled: false),
            (focused: false, invalid: false, disabled: true)
        ]

        for state in states {
            let view = TextField("Email", text: .constant(""))
                .dpInputChrome(
                    isFocused: state.focused,
                    isInvalid: state.invalid,
                    isDisabled: state.disabled
                )
            expectMinimumTouchTarget(fittingSize(of: view), name: "input \(state)")
        }
    }

    @Test
    func brandMarkMeetsTheMinimumTouchTarget() {
        expectMinimumTouchTarget(
            fittingSize(of: DPBrandMark(action: {})),
            name: "brand mark"
        )
    }

    @Test
    func brandMarkExposesOneAccessibilityElementForItsCompoundContent() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Components/DPBrandChrome.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let brandMark = try #require(source.range(of: "struct DPBrandMark: View"))
        let declaration = source[brandMark.lowerBound...]

        #expect(declaration.contains(".accessibilityElement(children: .ignore)"))
    }

    @Test
    func primaryTabIdentifierBelongsToTheActionableLabel() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/App/RootTabView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        let primaryTabItem = try #require(source.range(of: "func primaryTabItem(_ tab: AppTab)"))
        let declaration = source[primaryTabItem.lowerBound...]
        let labelIdentifierContract = [
            "Image(systemName: tab.systemImage)",
            "            }",
            "            .accessibilityIdentifier(tab.accessibilityIdentifier)"
        ].joined(separator: "\n")
        let imageIdentifierContract = [
            "Image(systemName: tab.systemImage)",
            "                .accessibilityIdentifier(tab.accessibilityIdentifier)"
        ].joined(separator: "\n")

        #expect(declaration.contains(labelIdentifierContract))
        #expect(!declaration.contains(imageIdentifierContract))
    }

    @Test
    func dashboardHeaderChromeDoesNotUseTheSystemSharedBackground() {
        #expect(DPDashboardHeaderChrome.sharedBackgroundVisibility == SwiftUI.Visibility.hidden)
    }

    @Test
    func customFontsAreBundledUnderTheirPostScriptNames() {
        #expect(DPFont.lightPostScriptName != DPFont.boldPostScriptName)
        #expect(UIFont(name: DPFont.lightPostScriptName, size: 16) != nil)
        #expect(UIFont(name: DPFont.boldPostScriptName, size: 16) != nil)
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
