import SwiftUI

nonisolated enum SettingsLocalization {
    static func string(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Settings", locale: locale)
    }

    static func text(_ key: String) -> Text {
        Text(verbatim: string(key))
    }
}
