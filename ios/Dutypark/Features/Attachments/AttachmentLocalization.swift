enum AttachmentLocalization {
    nonisolated static func text(_ key: String) -> String {
        AppLocalization.string(key, table: "Attachments")
    }

    nonisolated static func format(_ key: String, _ arguments: CVarArg...) -> String {
        AppLocalization.format(key, table: "Attachments", arguments: arguments)
    }
}
