import Foundation
import Testing
@testable import Dutypark

struct MoreAppVersionTests {
    private let korean = Locale(identifier: "ko")
    private let english = Locale(identifier: "en")

    @Test
    func versionFooterShowsOnlyTheMarketingVersion() {
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: "34", locale: korean)
                == "버전 1.2.0"
        )
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: "34", locale: english)
                == "Version 1.2.0"
        )
    }

    @Test
    func versionFooterIgnoresTheBuildNumberWhenMarketingVersionIsValid() {
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: "1.2.0", locale: english)
                == "Version 1.2.0"
        )
        #expect(
            MoreAppVersion.displayText(shortVersion: "1.2.0", build: nil, locale: english)
                == "Version 1.2.0"
        )
        #expect(
            MoreAppVersion.displayText(shortVersion: " 1.2.0 ", build: "   ", locale: english)
                == "Version 1.2.0"
        )
    }

    @Test
    func versionFooterIsHiddenWithoutAMarketingVersion() {
        #expect(MoreAppVersion.displayText(shortVersion: nil, build: "34", locale: english) == nil)
        #expect(MoreAppVersion.displayText(shortVersion: "   ", build: "34", locale: english) == nil)
    }

    @Test
    func installedBundleExposesItsOwnVersion() {
        #expect(MoreAppVersion.displayText != nil)
    }

    @Test
    func buildMetadataFormatsVersionDateAndCommitForInformationSection() throws {
        let metadata = try #require(AppBuildMetadata(
            shortVersion: "1.2.0",
            buildNumber: "34",
            buildDate: "2026-09-16 01:23 KST",
            commitHash: "abc1234",
            sourceState: .clean
        ))

        #expect(metadata.versionText == "1.2.0 (34)")
        #expect(metadata.dateText == "2026-09-16 01:23 KST")
        #expect(metadata.commitText(locale: english) == "abc1234")
    }

    @Test
    func buildMetadataMarksTrackedSourceChangesWithoutChangingTheCommitHash() throws {
        let metadata = try #require(AppBuildMetadata(
            shortVersion: "1.2.0",
            buildNumber: "34",
            buildDate: "2026-09-16 01:23 KST",
            commitHash: "abc1234",
            sourceState: .modified
        ))

        #expect(metadata.commitText(locale: english) == "abc1234 (modified)")
        #expect(metadata.commitText(locale: korean) == "abc1234 (수정됨)")
    }

    @Test
    func buildMetadataReadsGeneratedValuesFromTheApplicationInfoDictionary() throws {
        let metadata = try #require(AppBuildMetadata(infoDictionary: [
            "CFBundleShortVersionString": "1.2.0",
            "CFBundleVersion": "34",
            AppBuildMetadata.buildDateKey: "2026-09-16 01:23 KST",
            AppBuildMetadata.commitHashKey: "abc1234",
            AppBuildMetadata.sourceStateKey: "clean",
        ]))

        #expect(metadata.versionText == "1.2.0 (34)")
        #expect(metadata.dateText == "2026-09-16 01:23 KST")
        #expect(metadata.commitText(locale: english) == "abc1234")
    }

    @Test
    func installedApplicationBundleContainsGeneratedBuildMetadata() throws {
        let info = try #require(Bundle.main.infoDictionary)
        let buildDate = try #require(info[AppBuildMetadata.buildDateKey] as? String)
        let commitHash = try #require(info[AppBuildMetadata.commitHashKey] as? String)

        #expect(!buildDate.isEmpty)
        #expect(!commitHash.isEmpty)
    }
}
