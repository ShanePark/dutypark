import Foundation

nonisolated enum AdminLocalization {
    static func string(_ key: String, locale: Locale? = nil) -> String {
        AppLocalization.string(key, table: "Admin", locale: locale)
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.format(key, table: "Admin", arguments: arguments)
    }
}
