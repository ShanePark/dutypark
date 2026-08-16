import Foundation
import Testing
@testable import Dutypark

struct AdminWebViewTests {
    @Test("Embedded web preferences follow the app language and explicit dark theme")
    func resolvesKoreanDarkPreferences() {
        let preferences = AdminWebPreferences.resolve(
            languageCode: "ko",
            preferredLanguages: ["en-US"],
            themeCode: "dark",
            systemIsDark: false
        )

        #expect(preferences.locale == "ko")
        #expect(preferences.theme == "dark")
    }

    @Test("System theme follows the active native appearance")
    func resolvesSystemTheme() {
        #expect(AdminWebPreferences.resolve(
            languageCode: "",
            preferredLanguages: ["ko-KR"],
            themeCode: "system",
            systemIsDark: true
        ) == AdminWebPreferences(locale: "ko", theme: "dark"))

        #expect(AdminWebPreferences.resolve(
            languageCode: "en",
            preferredLanguages: ["ko-KR"],
            themeCode: "unexpected",
            systemIsDark: false
        ) == AdminWebPreferences(locale: "en", theme: "light"))
    }

    @Test("Document-start injection uses the frontend storage and embedded DOM contracts")
    func documentStartInjectionContract() {
        let source = AdminWebDocumentStartScript.source(
            allowedOrigin: "https://dutypark.test",
            preferences: AdminWebPreferences(locale: "ko", theme: "dark")
        )

        #expect(source.contains("window.location.origin !== expectedOrigin"))
        #expect(source.contains("localStorage.setItem('dp-locale', locale)"))
        #expect(source.contains("localStorage.setItem('theme', theme)"))
        #expect(source.contains("classList.toggle('dark', theme === 'dark')"))
        #expect(source.contains("classList.add('dp-ios-embedded')"))

        for selector in AdminWebDocumentStartScript.embeddedSelectors {
            #expect(source.contains(selector), "Missing embedded selector: \(selector)")
        }
    }

    @Test("Admin web destinations share the responsive web origin")
    func destinationURLs() throws {
        let apiBaseURL = try #require(URL(string: "https://dutypark.test/api/"))

        #expect(
            AdminWebDestination.url(path: "/admin/dev", apiBaseURL: apiBaseURL)?.absoluteString
                == "https://dutypark.test/admin/dev"
        )
        #expect(
            AdminWebDestination.apiDocumentationURL(apiBaseURL: apiBaseURL).absoluteString
                == "https://dutypark.test/docs/index.html"
        )
    }
}
