import Foundation

/// The app follows the system language (Settings > Dutypark > Language), so lookups
/// resolve against `Bundle.main`. Callers that need a specific language - server
/// content requests and copy tests - pass an explicit locale.
nonisolated enum AppLocalization {
    static var locale: Locale {
        supportedLocale(languageCode: Bundle.main.preferredLocalizations.first ?? "")
    }

    /// Narrows an arbitrary language tag to the two languages the app ships.
    static func supportedLocale(
        languageCode: String,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> Locale {
        let candidate = languageCode.isEmpty ? (preferredLanguages.first ?? "en") : languageCode
        return Locale(identifier: candidate.lowercased().hasPrefix("ko") ? "ko" : "en")
    }

    static func string(_ key: String, table: String, locale override: Locale? = nil) -> String {
        bundle(for: override).localizedString(forKey: key, value: key, table: table)
    }

    static func bundle(for locale: Locale? = nil) -> Bundle {
        guard let locale else { return .main }
        let language = supportedLocale(languageCode: locale.identifier).identifier
        guard let url = Bundle.main.url(forResource: language, withExtension: "lproj"),
              let bundle = Bundle(url: url)
        else { return .main }
        return bundle
    }

    static func format(
        _ key: String,
        table: String,
        arguments: [CVarArg],
        locale override: Locale? = nil
    ) -> String {
        String(
            format: string(key, table: table, locale: override),
            locale: override ?? locale,
            arguments: arguments
        )
    }
}
