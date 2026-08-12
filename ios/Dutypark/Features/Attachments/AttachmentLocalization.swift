enum AttachmentLocalization {
    nonisolated static func text(_ key: String) -> String {
        AppLocalization.string(key, table: "Attachments")
    }
}
