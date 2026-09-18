import Foundation

/// Version footer for the "more" tab. It shows the marketing version used for the release.
nonisolated enum MoreAppVersion {
    static var displayText: String? {
        displayText(metadata: AppBuildMetadata.current)
    }

    static func displayText(
        metadata: AppBuildMetadata?,
        locale: Locale? = nil
    ) -> String? {
        guard let metadata else { return nil }
        return displayText(
            shortVersion: metadata.shortVersion,
            build: metadata.buildNumber,
            locale: locale
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
