import Combine
import Foundation

/// Serves the cached banned word list immediately and refreshes it once per launch, so a list update
/// reaches the app without a release. A cold launch with no cache and no network uses the bundled list
/// so content filtering remains effective while offline.
@MainActor
final class ContentFilterStore: ObservableObject {
    static let shared = ContentFilterStore()

    @Published private(set) var words: [String]

    private let service: any PublicContentServicing
    private let defaults: UserDefaults
    private var loadTask: Task<Void, Never>?

    init(
        service: any PublicContentServicing = PublicContentService(),
        defaults: UserDefaults = .standard
    ) {
        self.service = service
        self.defaults = defaults
        if let cachedWords = defaults.stringArray(forKey: Self.cacheKey) {
            let normalizedCachedWords = ContentFilter.normalizedWords(cachedWords)
            if normalizedCachedWords.isEmpty {
                self.words = Self.bundledWords
            } else {
                self.words = normalizedCachedWords
                if normalizedCachedWords != cachedWords {
                    defaults.set(normalizedCachedWords, forKey: Self.cacheKey)
                }
            }
        } else {
            self.words = Self.bundledWords
        }
    }

    /// Returns the in-flight load so a caller that needs the fresh list - a test, mainly - can await it.
    @discardableResult
    func load() -> Task<Void, Never> {
        if let loadTask { return loadTask }

#if DEBUG
        guard !Self.shouldSkipNetworkRefresh(arguments: ProcessInfo.processInfo.arguments) else {
            return Task {}
        }
#endif

        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.loadTask = nil }
            do {
                let content = try await self.service.bannedWords()
                let normalizedWords = ContentFilter.normalizedWords(content.words)
                guard !normalizedWords.isEmpty else { return }
                self.words = normalizedWords
                self.defaults.set(normalizedWords, forKey: Self.cacheKey)
            } catch {
                // Keep the cached list, or the bundled safety list on a cold offline launch.
            }
        }
        loadTask = task
        return task
    }

    func blockedWord(in values: [String?]) -> String? {
        ContentFilter.bannedWord(in: values, words: words)
    }

    func isBlocked(_ values: String?...) -> Bool {
        blockedWord(in: values) != nil
    }

#if DEBUG
    nonisolated static func shouldSkipNetworkRefresh(arguments: [String]) -> Bool {
        arguments.contains { $0.hasPrefix("-ui-testing-") }
    }
#endif

    private static let cacheKey = "dp-banned-words"

    private struct BannedWordsResource: Decodable {
        let schemaVersion: Int
        let words: [String]
    }

    /// The server resource is shipped with the app as a last-known-good safety list. The static
    /// fallback keeps filtering fail-closed even if a malformed/missing bundle resource is ever
    /// produced; it mirrors the canonical resource and is intentionally not used after a cache or
    /// successful network response is available.
    private static let bundledWords: [String] = {
        let bundles = [Bundle(for: ContentFilterStore.self), Bundle.main]
        for bundle in bundles {
            guard let url = bundle.url(forResource: "banned-words", withExtension: "json"),
                  let data = try? Data(contentsOf: url),
                  let resource = try? JSONDecoder().decode(BannedWordsResource.self, from: data),
                  resource.schemaVersion == 1
            else { continue }
            let normalizedWords = ContentFilter.normalizedWords(resource.words)
            guard !normalizedWords.isEmpty else { continue }
            return normalizedWords
        }

        return ContentFilter.normalizedWords(ContentFilterStore.emergencyWords)
    }()

    private static let emergencyWords = [
        "시발", "씨발", "시팔", "씨팔", "쓰발", "개새끼", "개소리", "병신", "븅신", "지랄",
        "좆", "썅", "미친놈", "미친년", "창녀", "매춘", "강간", "야동", "짱깨", "쪽바리",
        "쪽발이", "조센징", "틀딱", "한남충", "김치녀", "된장녀", "맘충", "급식충", "fuck", "shit",
        "bitch", "cunt", "nigger", "nigga", "faggot", "retard", "whore", "slut", "pussy", "porn",
        "blowjob", "asshole", "bastard", "dickhead", "wanker", "twat",
    ]
}
