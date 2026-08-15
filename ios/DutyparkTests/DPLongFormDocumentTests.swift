import Foundation
import Testing
@testable import Dutypark

@Suite("Long-form policy documents")
struct DPLongFormDocumentTests {
    @Test
    func parserKeepsDocumentHierarchyAndListOrder() {
        let blocks = DPLongFormMarkdownParser.parse(
            """
            # Dutypark policy

            Introductory **copy**.

            ## Scope

            1. First item
            2. Second item

            - Optional item
            - Another item
            """
        )

        #expect(blocks == [
            .heading(level: 1, text: "Dutypark policy"),
            .paragraph("Introductory **copy**."),
            .heading(level: 2, text: "Scope"),
            .orderedList([
                .init(marker: "1.", text: "First item"),
                .init(marker: "2.", text: "Second item"),
            ]),
            .unorderedList([
                .init(marker: "•", text: "Optional item"),
                .init(marker: "•", text: "Another item"),
            ]),
        ])
    }

    @Test
    func parserTurnsWideMarkdownTablesIntoLabeledRows() {
        let blocks = DPLongFormMarkdownParser.parse(
            """
            | Category | Collected data | Purpose |
            | --- | :--- | ---: |
            | Account | Name and identifier | Sign-in and account management |
            | Schedule | Date and long schedule content | Calendar features |
            """
        )

        #expect(blocks == [
            .table(
                headers: ["Category", "Collected data", "Purpose"],
                rows: [
                    ["Account", "Name and identifier", "Sign-in and account management"],
                    ["Schedule", "Date and long schedule content", "Calendar features"],
                ]
            ),
        ])
    }

    @Test
    func parserPreservesIntentionalLineBreaksAndSeparators() {
        let blocks = DPLongFormMarkdownParser.parse(
            "First line\r\nsecond line\r\n\r\n---\r\n\r\nFinal paragraph"
        )

        #expect(blocks == [
            .paragraph("First line\nsecond line"),
            .separator,
            .paragraph("Final paragraph"),
        ])
    }

    @Test
    func compactAndRegularStylesKeepReadableDynamicTypeContracts() {
        #expect(DPLongFormDocumentStyle.regular.bodySize == 16)
        #expect(DPLongFormDocumentStyle.regular.lineSpacing >= 5)
        #expect(DPLongFormDocumentStyle.regular.blockSpacing >= 12)
        #expect(DPLongFormDocumentStyle.compact.bodySize == 13)
        #expect(DPLongFormDocumentStyle.compact.lineSpacing >= 3)
        #expect(DPLongFormDocumentStyle.compact.blockSpacing < DPLongFormDocumentStyle.regular.blockSpacing)
        #expect(DPLongFormDocumentLayout.horizontalPadding >= 20)
    }

    @Test
    func everyNativePolicySurfaceUsesTheSharedRenderer() throws {
        let sourceRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features")
        let settings = try String(
            contentsOf: sourceRoot.appending(path: "Settings/SettingsView.swift"),
            encoding: .utf8
        )
        let guest = try String(
            contentsOf: sourceRoot.appending(path: "Guest/GuestPolicyView.swift"),
            encoding: .utf8
        )
        let signup = try String(
            contentsOf: sourceRoot.appending(path: "Auth/SsoSignupView.swift"),
            encoding: .utf8
        )

        #expect(settings.components(separatedBy: "DPLongFormDocument(").count - 1 >= 3)
        #expect(!settings.contains("AttributedString(markdown: policy.content)"))
        #expect(guest.contains("DPLongFormDocument("))
        #expect(!guest.contains("Text(markdown(policy.content))"))
        #expect(signup.components(separatedBy: "DPLongFormDocument(").count - 1 >= 2)
        #expect(!signup.contains("private func policyText("))
    }

    @Test
    func rendererKeepsSelectionWrappingAndBlockAccessibilityContracts() throws {
        let component = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Components/DPLongFormDocument.swift"),
            encoding: .utf8
        )

        #expect(component.contains(".textSelection(.enabled)"))
        #expect(component.contains(".fixedSize(horizontal: false, vertical: true)"))
        #expect(component.contains(".accessibilityAddTraits(.isHeader)"))
        #expect(component.contains(".accessibilityElement(children: .combine)"))
        #expect(component.contains("dp.longForm.table."))
    }

    @Test
    func settingsProvidesDebugOnlyDirectRoutesForLongFormPolicyVerification() throws {
        let settings = try String(
            contentsOf: URL(fileURLWithPath: #filePath)
                .deletingLastPathComponent()
                .deletingLastPathComponent()
                .appending(path: "Dutypark/Features/Settings/SettingsView.swift"),
            encoding: .utf8
        )

        #expect(settings.contains("-ui-testing-long-form-policy-terms"))
        #expect(settings.contains("-ui-testing-long-form-policy-privacy"))
        #expect(settings.contains("destination = .terms"))
        #expect(settings.contains("destination = .privacy"))
    }
}
