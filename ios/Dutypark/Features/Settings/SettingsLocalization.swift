import SwiftUI

nonisolated enum SettingsLocalization {
    static func string(_ key: String) -> String {
        NSLocalizedString(
            key,
            tableName: "Settings",
            bundle: selectedBundle,
            value: key,
            comment: ""
        )
    }

    static func text(_ key: String) -> Text {
        Text(verbatim: string(key))
    }

    private static var selectedLocale: Locale {
        guard let language = UserDefaults.standard.string(forKey: "dp-language"),
              !language.isEmpty
        else { return .current }
        return Locale(identifier: language)
    }

    private static var selectedBundle: Bundle {
        guard let path = Bundle.main.path(
            forResource: selectedLocale.identifier,
            ofType: "lproj"
        ), let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
