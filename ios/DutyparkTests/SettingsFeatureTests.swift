import Foundation
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct SettingsFeatureTests {
    @Test
    func supportsTheSameFiveNativeLanguageChoicesAsWeb() {
        #expect(AppLanguage.allCases.map(\.rawValue) == ["ko", "en", "ja", "zh-Hans", "es"])
        #expect(AppLanguage.allCases.map(\.nativeName) == ["한국어", "English", "日本語", "简体中文", "Español"])
    }

    @Test
    func supportsSystemLightAndDarkAppearanceChoices() {
        #expect(AppTheme.allCases.map(\.rawValue) == ["system", "light", "dark"])
        #expect(SettingsPreference.defaultTheme == AppTheme.system.rawValue)
        #expect(AppTheme.system.preferredColorScheme == nil)
        #expect(AppTheme.light.preferredColorScheme == .light)
        #expect(AppTheme.dark.preferredColorScheme == .dark)
    }

    @Test
    func resolvesSettingsCopyFromTheSettingsCatalog() {
        let key = "settings.profile.title"

        #expect(SettingsLocalization.string(key) != key)
    }

    @Test
    func webParitySettingsCopyExistsInEverySupportedLanguage() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        let keys = [
            "settings.profile.name",
            "settings.visibility.modalTitle",
            "settings.visibility.private.description",
            "settings.theme.system",
            "settings.theme.current.system",
            "settings.theme.current.dark",
            "settings.pattern.title",
            "settings.pattern.createDescription",
            "settings.pattern.saveConfirm",
            "settings.pattern.deleteConfirm",
            "settings.accessibility.on",
            "settings.accessibility.off",
        ]
        for language in AppLanguage.allCases {
            defaults.set(language.rawValue, forKey: SettingsPreference.languageKey)
            for key in keys {
                #expect(SettingsLocalization.string(key) != key)
            }
        }
    }

    @Test
    func localizationHelpersFollowTheExplicitAppLanguage() {
        let defaults = UserDefaults.standard
        let previous = defaults.string(forKey: SettingsPreference.languageKey)
        defer {
            if let previous { defaults.set(previous, forKey: SettingsPreference.languageKey) }
            else { defaults.removeObject(forKey: SettingsPreference.languageKey) }
        }

        defaults.set("ko", forKey: SettingsPreference.languageKey)

        #expect(SettingsLocalization.string("settings.guide") == "사용 가이드")
        #expect(GuestLocalization.text("guest.retry") == "다시 시도")
        #expect(SettingsLocalization.string("settings.guide.loadError.title") == "페이지를 불러올 수 없습니다")
    }

    @Test
    func decodesSessionWithoutKeepingServerTokenValue() throws {
        let data = Data(
            #"{"memberName":"Test","memberId":1,"validUntil":"2026-09-01T10:00:00","createdDate":"2026-08-01T10:00:00","lastUsed":null,"remoteAddr":"127.0.0.1","id":9,"token":"server-secret","userAgent":{"os":"iOS","browser":"Dutypark","device":"iPhone"},"isCurrentLogin":true}"#.utf8
        )

        let session = try JSONDecoder().decode(SettingsRefreshToken.self, from: data)

        #expect(session.id == 9)
        #expect(session.userAgent?.device == "iPhone")
        #expect(session.isCurrentLogin == true)
    }

    @Test
    func decodesDutyPatternUsedByTheSettingsCard() throws {
        let data = Data(
            ##"{"configurable":true,"reason":null,"dutyTypes":[{"id":4,"name":"Day","color":"#3B82F6"}],"pattern":{"days":[{"weekday":"MONDAY","dutyType":{"id":4,"name":"Day","color":"#3B82F6"}}],"holidayOff":true,"effectiveFrom":"2026-08-01"}}"##.utf8
        )

        let pattern = try JSONDecoder().decode(DutyPatternDTO.self, from: data)

        #expect(pattern.configurable)
        #expect(pattern.pattern?.days.first?.weekday == .monday)
        #expect(pattern.pattern?.holidayOff == true)
    }

    @Test
    func cropsAProfilePhotoToASquareJpeg() throws {
        let image = UIGraphicsImageRenderer(size: CGSize(width: 200, height: 100)).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(x: 0, y: 0, width: 200, height: 100))
        }

        let data = try #require(
            ProfilePhotoCropper.jpeg(
                image: image,
                viewport: 300,
                zoom: 1,
                offset: .zero
            )
        )
        let cropped = try #require(UIImage(data: data)?.cgImage)

        #expect(cropped.width == cropped.height)
    }

    @Test
    func clampsPhotoMovementInsideTheCropArea() {
        let offset = ProfilePhotoCropper.clampedOffset(
            CGSize(width: 1_000, height: -1_000),
            imageSize: CGSize(width: 200, height: 100),
            viewport: 300,
            zoom: 1
        )

        #expect(offset.width == 150)
        #expect(offset.height == 0)
    }
}
