import Foundation
import Testing
@testable import Dutypark

/// Settings holds app and device preferences, My Info holds preferences stored on the
/// account, and More ends with the service documents. These markers pin each item to
/// its screen so the three do not drift back together.
struct InformationArchitectureTests {
    @Test("Settings keeps only the app and device preferences")
    func settingsKeepsDevicePreferencesOnly() throws {
        let settings = try source("Dutypark/Features/Settings/SettingsView.swift")
        let body = try #require(settings.range(of: "private var appearanceSection"))
        let screen = String(settings[..<body.lowerBound])

        for kept in ["appearanceSection", "pushSection", "languageSection"] {
            #expect(screen.contains(kept), "\(kept) should stay in Settings")
        }
        for moved in [
            "visibilitySection",
            "aiConsentSection",
            "informationSection",
            "\"settings.guide\"",
            "\"settings.releaseNotes\"",
            "buildMetadataSection",
            // Terms and privacy stay reachable from deep links, but Settings no longer
            // lists any document links of its own.
            "settingsNavigationLink(",
        ] {
            #expect(!settings.contains(moved), "\(moved) should no longer render in Settings")
        }
    }

    @Test("My Info owns the calendar visibility and AI time parsing consent")
    func myInfoOwnsAccountStoredPreferences() throws {
        let myInfo = try source("Dutypark/Features/Settings/MyInfoView.swift")

        #expect(myInfo.contains("SettingsCard(title: \"settings.visibility.title\""))
        #expect(myInfo.contains("SettingsCard(title: \"settings.aiConsent.title\""))
        #expect(myInfo.contains("VisibilitySettingsModal("))
        #expect(myInfo.contains("AIScheduleConsentActivationModal("))
        #expect(myInfo.contains("AIScheduleConsentPolicyView("))
    }

    @Test("My Info loads the friends behind the visibility audience; Settings does not")
    func loadPlansFollowTheSections() {
        #expect(SettingsLoadPlan.myInfo.friends)
        #expect(!SettingsLoadPlan.settings.friends)
    }

    @Test("More ends with a quiet terms, privacy and version footer")
    func moreEndsWithPolicyFooter() throws {
        let more = try source("Dutypark/Features/More/MoreView.swift")

        #expect(more.contains("GuestPolicyView(type: .terms)"))
        #expect(more.contains("GuestPolicyView(type: .privacy)"))
        #expect(more.contains("\"more.terms\""))
        #expect(more.contains("\"more.privacy\""))
        #expect(more.contains("\"more.appVersion\""))
        #expect(!MoreMenuItem.allCases.map(\.rawValue).contains("terms"))
    }

    @Test("The guide carries the release notes as a second segment for every visitor")
    func guideCarriesReleaseNotesSegment() throws {
        let content = try source("Dutypark/Features/Settings/PublicContentViews.swift")
        let guestRoot = try source("Dutypark/Features/Guest/GuestRootView.swift")
        let guestGuide = root.appending(path: "Dutypark/Features/Guest/GuestGuideView.swift")

        #expect(content.contains("\"guide.sectionPicker\""))
        #expect(content.contains("PublicReleaseNotesView(service: service)"))
        #expect(guestRoot.contains("PublicGuideView("))
        #expect(!FileManager.default.fileExists(atPath: guestGuide.path))
    }

    @Test("Guide and support entries use one label everywhere")
    func guideAndSupportLabelsAreUnified() {
        #expect(SettingsLocalization.string("settings.guide", locale: .korean) == "이용 안내")
        #expect(SettingsLocalization.string("settings.guide", locale: .english) == "Guide")
        #expect(RootChromeLocalization.localizable("root.menu.guide", locale: .korean) == "이용 안내")
        #expect(
            RootChromeLocalization.localizable("root.menu.support", locale: .korean) == "문의·지원"
        )
        #expect(SupportLocalization.text("support.title", locale: .korean) == "문의·지원")
        #expect(
            RootChromeLocalization.localizable("root.menu.support", locale: .english) == "Support"
        )
    }

    @Test("Strings for the removed Settings rows are gone from the catalogs")
    func removedSettingsRowsLeaveNoStrings() throws {
        let settings = try source("Dutypark/Resources/Settings.xcstrings")
        let guest = try source("Dutypark/Features/Guest/Guest.xcstrings")

        for key in [
            "settings.information.title",
            "settings.buildInfo.title",
            "settings.buildInfo.version",
            "settings.buildInfo.date",
            "settings.buildInfo.commit",
        ] {
            #expect(!settings.contains("\"\(key)\""), "\(key) is no longer shown anywhere")
        }
        // The build metadata row in More still formats these two.
        #expect(settings.contains("\"settings.buildInfo.modified\""))
        #expect(settings.contains("\"settings.buildInfo.unknown\""))
        #expect(!guest.contains("\"guest.guide.title\""), "the guest guide now uses settings.guide")
    }

    @Test("Social sign-in status uses the web wording")
    func socialConnectedLabelMatchesWeb() {
        #expect(SettingsLocalization.string("settings.social.connected", locale: .korean) == "연동됨")
        #expect(SettingsLocalization.string("settings.social.connected", locale: .english) == "Connected")
    }

    private var root: URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
    }

    private func source(_ path: String) throws -> String {
        try String(contentsOf: root.appending(path: path), encoding: .utf8)
    }
}
