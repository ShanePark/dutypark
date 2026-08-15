import Foundation
import Testing
@testable import Dutypark

struct NativeContentBoundaryTests {
    @Test("Only authenticated admin tools may embed a web view")
    func productionWebKitUsageIsRestrictedToAdminTools() throws {
        let iosDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let sourceDirectory = iosDirectory.appending(path: "Dutypark")
        let enumerator = try #require(FileManager.default.enumerator(
            at: sourceDirectory,
            includingPropertiesForKeys: nil
        ))

        var webKitSources: [String] = []
        for case let file as URL in enumerator where file.pathExtension == "swift" {
            let source = try String(contentsOf: file, encoding: .utf8)
            if source.contains("import WebKit") || source.contains("WKWebView") {
                webKitSources.append(file.lastPathComponent)
            }
        }

        #expect(webKitSources.sorted() == ["AdminWebView.swift"])
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

    @Test("Admin navigation preserves the four responsive-web destinations")
    func adminMenuMatchesResponsiveWeb() {
        #expect(AdminRootNavigationPresentation.tileKeys == [
            "admin.nav.members",
            "admin.nav.teams",
            "admin.nav.development",
            "admin.nav.apiDocumentation",
        ])
    }

    private func source(_ path: String, under directory: URL) throws -> String {
        try String(contentsOf: directory.appending(path: path), encoding: .utf8)
    }
}
