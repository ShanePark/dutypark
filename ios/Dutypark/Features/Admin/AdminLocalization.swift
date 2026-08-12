import Foundation

nonisolated enum AdminLocalization {
    static func string(_ key: String) -> String {
        AppLocalization.string(key, table: "Admin")
    }

    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.format(key, table: "Admin", arguments: arguments)
    }
}
