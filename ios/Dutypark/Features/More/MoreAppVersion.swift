import Foundation

/// Version footer for the "more" tab. It shows the marketing version used for the release.
nonisolated enum MoreAppVersion {
    static var displayText: String? {
        displayText(
            shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    static func displayText(
        shortVersion: String?,
        build _: String?,
        locale: Locale? = nil
    ) -> String? {
        guard let version = nonempty(shortVersion) else { return nil }

        let selectedLocale = locale ?? AppLocalization.locale
        return String(
            format: RootChromeLocalization.localizable("root.more.version", locale: selectedLocale),
            locale: selectedLocale,
            arguments: [version]
        )
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
