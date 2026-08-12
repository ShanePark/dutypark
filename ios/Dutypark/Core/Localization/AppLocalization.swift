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
        String(
            localized: String.LocalizationValue(key),
            table: table,
            locale: override ?? locale
        )
    }

    static func format(_ key: String, table: String, arguments: [CVarArg]) -> String {
        String(
            format: string(key, table: table),
            locale: locale,
            arguments: arguments
        )
    }
}
