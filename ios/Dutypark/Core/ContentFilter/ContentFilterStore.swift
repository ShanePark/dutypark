import Combine
import Foundation

/// Serves the cached banned word list immediately and refreshes it once per launch, so a list update
/// reaches the app without a release. A cold launch with no cache and no network leaves the list empty,
/// and an empty list blocks nothing: availability wins over a check the server does not enforce anyway.
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
        self.words = defaults.stringArray(forKey: Self.cacheKey) ?? []
    }

    /// Returns the in-flight load so a caller that needs the fresh list - a test, mainly - can await it.
    @discardableResult
    func load() -> Task<Void, Never> {
        if let loadTask { return loadTask }

        let task = Task { [weak self] in
            guard let self else { return }
            defer { self.loadTask = nil }
            do {
                let content = try await self.service.bannedWords()
                self.words = content.words
                self.defaults.set(content.words, forKey: Self.cacheKey)
            } catch {
                // Keep whatever the cache already provided.
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

    private static let cacheKey = "dp-banned-words"
}
