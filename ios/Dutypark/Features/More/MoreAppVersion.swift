import Foundation

/// Version footer for the "more" tab. The build number is shown next to the marketing
/// version so support requests can name the exact installed build.
nonisolated enum MoreAppVersion {
    static var displayText: String? {
        displayText(
            shortVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String,
            build: Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        )
    }

    static func displayText(
        shortVersion: String?,
        build: String?,
        locale: Locale? = nil
    ) -> String? {
        guard let version = nonempty(shortVersion) else { return nil }

        var value = version
        if let buildNumber = nonempty(build), buildNumber != version {
            value += " (\(buildNumber))"
        }

        let selectedLocale = locale ?? AppLocalization.locale
        return String(
            format: RootChromeLocalization.localizable("root.more.version", locale: selectedLocale),
            locale: selectedLocale,
            arguments: [value]
        )
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
