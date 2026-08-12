import Foundation

nonisolated enum AppLocalization {
    private static let languageKey = "dp-language"

    static var locale: Locale {
        guard let language = UserDefaults.standard.string(forKey: languageKey),
              !language.isEmpty
        else { return .current }
        return Locale(identifier: language)
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
        let language: String
        if identifier.hasPrefix("zh") {
            language = "zh-Hans"
        } else if identifier.hasPrefix("ko") {
            language = "ko"
        } else if identifier.hasPrefix("ja") {
            language = "ja"
        } else if identifier.hasPrefix("es") {
            language = "es"
        } else if identifier.hasPrefix("en") {
            language = "en"
        } else {
            return nil
        }
        guard let url = Bundle.main.url(forResource: language, withExtension: "lproj") else {
            return nil
        }
        return Bundle(url: url)
    }
}
