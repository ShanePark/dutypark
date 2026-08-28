import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite("Content filter", .serialized)
struct ContentFilterTests {
    @Test("Normalization strips the decoration a banned word can hide behind")
    func normalizes() {
        #expect(ContentFilter.normalizeForMatching("F U C K") == "fuck")
        #expect(ContentFilter.normalizeForMatching("시.발!") == "시발")
        #expect(ContentFilter.normalizeForMatching("ＦＵＣＫ") == "fuck")
        #expect(ContentFilter.normalizeForMatching("시〇발") == "시발")
        #expect(ContentFilter.normalizeForMatching("v2") == "v2")
        #expect(ContentFilter.normalizeForMatching("!!!") == "")
    }

    @Test("Matching reports the first banned word across every value it is given")
    func matchesAcrossValues() {
        let words = ["시발", "fuck"]

        #expect(ContentFilter.bannedWord(in: ["제목", nil, "본문 시.발"], words: words) == "시발")
        #expect(ContentFilter.bannedWord(in: ["제목", "본문"], words: words) == nil)
        #expect(ContentFilter.bannedWord(in: ["시발"], words: []) == nil)
    }

#if DEBUG
    @Test("UI-test fixtures do not refresh the content filter over the network")
    func skipsNetworkRefreshForUITestingArguments() {
        #expect(ContentFilterStore.shouldSkipNetworkRefresh(arguments: ["-ui-testing-authenticated"]))
        #expect(ContentFilterStore.shouldSkipNetworkRefresh(arguments: ["-ui-testing-admin"]))
        #expect(!ContentFilterStore.shouldSkipNetworkRefresh(arguments: ["Dutypark"]))
    }
#endif

    @Test("The store loads the list once per launch and caches it for the next cold launch")
    func loadsOnceAndCaches() async {
        let defaults = makeDefaults()
        let service = BannedWordsServiceStub(result: .success(bannedWords(["시발"])))
        let store = ContentFilterStore(service: service, defaults: defaults)

        let first = store.load()
        let second = store.load()
        await first.value
        await second.value

        #expect(service.callCount == 1)
        #expect(store.isBlocked("오늘 시발 회식"))
        #expect(defaults.stringArray(forKey: cacheKey) == ["시발"])
    }

    @Test("The store checks with the cached list before the request resolves")
    func usesCacheBeforeLoad() {
        let defaults = makeDefaults()
        defaults.set(["시발"], forKey: cacheKey)
        let service = BannedWordsServiceStub(result: .success(bannedWords(["시발", "fuck"])))

        let store = ContentFilterStore(service: service, defaults: defaults)

        #expect(store.isBlocked("시발"))
        #expect(store.blockedWord(in: ["팀 회식"]) == nil)
    }

    @Test("The store keeps the cached list when the request fails, and blocks nothing without one")
    func failsOpen() async {
        let cachedDefaults = makeDefaults()
        cachedDefaults.set(["시발"], forKey: cacheKey)
        let cachedStore = ContentFilterStore(
            service: BannedWordsServiceStub(result: .failure(StubError.offline)),
            defaults: cachedDefaults
        )

        await cachedStore.load().value

        #expect(cachedStore.isBlocked("시발"))

        let coldStore = ContentFilterStore(
            service: BannedWordsServiceStub(result: .failure(StubError.offline)),
            defaults: makeDefaults()
        )

        await coldStore.load().value

        #expect(!coldStore.isBlocked("시발"))
    }

    private let cacheKey = "dp-banned-words"

    private func makeDefaults() -> UserDefaults {
        let suiteName = "content-filter-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }

    private func bannedWords(_ words: [String]) -> PublicBannedWords {
        PublicBannedWords(schemaVersion: 1, contentVersion: "abc", words: words)
    }
}

private enum StubError: Error {
    case offline
}

private final class BannedWordsServiceStub: PublicContentServicing, @unchecked Sendable {
    private let result: Result<PublicBannedWords, Error>
    private(set) var callCount = 0

    init(result: Result<PublicBannedWords, Error>) {
        self.result = result
    }

    func guide(locale: String) async throws -> PublicGuideContent {
        throw StubError.offline
    }

    func releaseNotes(locale: String, page: Int, size: Int) async throws -> PublicReleaseNotesPage {
        throw StubError.offline
    }

    func bannedWords() async throws -> PublicBannedWords {
        callCount += 1
        return try result.get()
    }
}
