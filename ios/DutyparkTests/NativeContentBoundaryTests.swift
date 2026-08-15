import Foundation
import Testing
@testable import Dutypark

struct NativeContentBoundaryTests {
    @Test("Production Swift sources do not embed web views")
    func productionHasNoWebKitUsage() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = iosDirectory.appending(path: "Dutypark")
        let enumerator = try #require(FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: nil
        ))

        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            #expect(!source.contains("import WebKit"), "WebKit import remains in \(file.lastPathComponent)")
            #expect(!source.contains("WKWebView"), "WKWebView remains in \(file.lastPathComponent)")
        }
    }

    @Test("Guest, settings, and authenticated deep-link routes render native content screens")
    func guideRoutesAreNative() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let guest = try source(
            "Dutypark/Features/Guest/GuestGuideView.swift",
            under: iosDirectory
        )
        let settings = try source(
            "Dutypark/Features/Settings/SettingsView.swift",
            under: iosDirectory
        )

        #expect(guest.contains("PublicGuideView(fallbackTitle:"))
        #expect(guest.contains("PublicReleaseNotesView()"))
        #expect(guest.contains("guest.guide.sectionPicker"))
        #expect(settings.contains("case .guide:\n                PublicGuideView()"))
        #expect(settings.contains("PublicReleaseNotesView()"))
    }

    @Test("Admin navigation exposes only native management destinations")
    func adminMenuIsNativeOnly() {
        #expect(AdminRootNavigationPresentation.tileKeys == [
            "admin.nav.members",
            "admin.nav.teams",
        ])
    }

    private func source(_ path: String, under directory: URL) throws -> String {
        try String(contentsOf: directory.appending(path: path), encoding: .utf8)
    }
}
