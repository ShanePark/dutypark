import Foundation

/// Build information written to the built application's Info.plist by Xcode.
///
/// The source tree intentionally contains no build timestamp or commit value. The build
/// phase writes those values to the application bundle so an installed build is identifiable
/// from the Information screen.
nonisolated struct AppBuildMetadata: Equatable, Sendable {
    nonisolated enum SourceState: String, Sendable {
        case clean
        case modified
        case unknown
    }

    static let buildDateKey = "DutyparkBuildDate"
    static let commitHashKey = "DutyparkGitCommit"
    static let sourceStateKey = "DutyparkSourceState"

    let shortVersion: String
    let buildNumber: String?
    let buildDate: String?
    let commitHash: String?
    let sourceState: SourceState

    init?(
        shortVersion: String?,
        buildNumber: String?,
        buildDate: String?,
        commitHash: String?,
        sourceState: SourceState
    ) {
        guard let shortVersion = Self.nonempty(shortVersion) else { return nil }

        self.shortVersion = shortVersion
        self.buildNumber = Self.nonempty(buildNumber)
        self.buildDate = Self.nonempty(buildDate)
        self.commitHash = Self.nonempty(commitHash)
        self.sourceState = sourceState
    }

    init?(infoDictionary: [String: Any]) {
        self.init(
            shortVersion: infoDictionary["CFBundleShortVersionString"] as? String,
            buildNumber: infoDictionary["CFBundleVersion"] as? String,
            buildDate: infoDictionary[Self.buildDateKey] as? String,
            commitHash: infoDictionary[Self.commitHashKey] as? String,
            sourceState: SourceState(
                rawValue: infoDictionary[Self.sourceStateKey] as? String ?? ""
            ) ?? .unknown
        )
    }

    static var current: Self? {
        Self(infoDictionary: Bundle.main.infoDictionary ?? [:])
    }

    var versionText: String {
        guard let buildNumber else { return shortVersion }
        return "\(shortVersion) (\(buildNumber))"
    }

    var dateText: String? {
        buildDate
    }

    func commitText(locale: Locale? = nil) -> String? {
        guard let commitHash else { return nil }

        switch sourceState {
        case .clean:
            return commitHash
        case .modified:
            let suffix = AppLocalization.string(
                "settings.buildInfo.modified",
                table: "Settings",
                locale: locale
            )
            return "\(commitHash) (\(suffix))"
        case .unknown:
            let suffix = AppLocalization.string(
                "settings.buildInfo.unknown",
                table: "Settings",
                locale: locale
            )
            return "\(commitHash) (\(suffix))"
        }
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}
