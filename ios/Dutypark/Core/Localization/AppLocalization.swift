import Foundation

nonisolated enum AppLocalization {
    private static let languageKey = "dp-language"

    static var locale: Locale {
        supportedLocale(
            languageCode: UserDefaults.standard.string(forKey: languageKey) ?? ""
        )
    }

    static func supportedLocale(
        languageCode: String,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        let candidate = languageCode.isEmpty ? (preferredLanguages.first ?? "en") : languageCode
        return Locale(identifier: candidate.lowercased().hasPrefix("ko") ? "ko" : "en")
    }

    static func string(_ key: String, table: String, locale override: Locale? = nil) -> String {
        let selectedLocale = override ?? locale
        if let bundle = localizedBundle(for: selectedLocale) {
            return bundle.localizedString(forKey: key, value: key, table: table)
        }
        return String(
            localized: String.LocalizationValue(key),
            table: table,
            locale: selectedLocale
        )
    }

    static func format(_ key: String, table: String, arguments: [CVarArg]) -> String {
        String(
            format: string(key, table: table),
            locale: locale,
            arguments: arguments
        )
    }

    private static func localizedBundle(for locale: Locale) -> Bundle? {
        let identifier = locale.identifier.lowercased()
        let language = identifier.hasPrefix("ko") ? "ko" : "en"
        guard let url = Bundle.main.url(forResource: language, withExtension: "lproj") else {
            return nil
        }
        return Bundle(url: url)
    }
}
