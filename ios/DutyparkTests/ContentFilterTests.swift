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

    @Test("The store keeps the cached list when the request fails and uses the bundled fallback")
    func keepsCachedListAndUsesBundledFallback() async {
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

        #expect(coldStore.isBlocked("시발"))
    }

    @Test("An empty network list never replaces the cached or bundled list")
    func keepsTheExistingListWhenTheNetworkReturnsNoWords() async throws {
        let cachedDefaults = makeDefaults()
        cachedDefaults.set(["시발"], forKey: cacheKey)
        let cachedStore = ContentFilterStore(
            service: BannedWordsServiceStub(result: .success(bannedWords([]))),
            defaults: cachedDefaults
        )

        await cachedStore.load().value

        #expect(cachedStore.isBlocked("시발"))
        #expect(cachedDefaults.stringArray(forKey: cacheKey) == ["시발"])

        let coldDefaults = makeDefaults()
        let coldStore = ContentFilterStore(
            service: BannedWordsServiceStub(result: .success(bannedWords([]))),
            defaults: coldDefaults
        )

        await coldStore.load().value

        #expect(coldStore.isBlocked("시발"))
        #expect(!coldStore.words.isEmpty)

        let invalidNetworkStore = ContentFilterStore(
            service: BannedWordsServiceStub(result: .success(bannedWords([""]))),
            defaults: makeDefaults()
        )

        await invalidNetworkStore.load().value

        #expect(invalidNetworkStore.isBlocked("시발"))
        #expect(!invalidNetworkStore.isBlocked("오늘"))
    }

    @Test("Cached words are normalized before they are used")
    func normalizesCachedWordsBeforeAdoptingThem() {
        let defaults = makeDefaults()
        defaults.set([" F U C K ", "", "f.u.c.k", "시.발", "시발"], forKey: cacheKey)

        let store = ContentFilterStore(
            service: BannedWordsServiceStub(result: .failure(StubError.offline)),
            defaults: defaults
        )

        #expect(store.words == ["fuck", "시발"])
        #expect(store.isBlocked("f.u.c.k"))
        #expect(store.isBlocked("시.발"))
        #expect(defaults.stringArray(forKey: cacheKey) == ["fuck", "시발"])

        let invalidDefaults = makeDefaults()
        invalidDefaults.set([""], forKey: cacheKey)
        let invalidStore = ContentFilterStore(
            service: BannedWordsServiceStub(result: .failure(StubError.offline)),
            defaults: invalidDefaults
        )

        #expect(invalidStore.isBlocked("시발"))
        #expect(!invalidStore.isBlocked("오늘"))
    }

    @Test("Network words are normalized before replacing the current list")
    func normalizesNetworkWordsBeforeAdoptingThem() async {
        let defaults = makeDefaults()
        let service = BannedWordsServiceStub(
            result: .success(bannedWords([" F U C K ", "", "f.u.c.k", "시.발", "시발"]))
        )
        let store = ContentFilterStore(service: service, defaults: defaults)

        await store.load().value

        #expect(store.words == ["fuck", "시발"])
        #expect(store.isBlocked("f.u.c.k"))
        #expect(store.isBlocked("시.발"))
        #expect(defaults.stringArray(forKey: cacheKey) == ["fuck", "시발"])
    }

    @Test("The app bundle ships a decodable non-empty banned-word resource")
    func bundledBannedWordsResourceIsValid() throws {
        let bundles = [Bundle(for: ContentFilterStore.self), Bundle.main]
        let url = try #require(
            bundles.compactMap { $0.url(forResource: "banned-words", withExtension: "json") }.first
        )
        let data = try Data(contentsOf: url)
        let resource = try JSONDecoder().decode(BundledBannedWordsResource.self, from: data)

        #expect(resource.schemaVersion == 1)
        #expect(!resource.words.isEmpty)
        #expect(resource.words.contains("시발"))

        let store = ContentFilterStore(
            service: BannedWordsServiceStub(result: .failure(StubError.offline)),
            defaults: makeDefaults()
        )
        let expectedWords = ContentFilter.normalizedWords(resource.words)
        #expect(store.words == expectedWords)
        #expect(store.words.allSatisfy { !$0.isEmpty })
        #expect(Set(store.words).count == store.words.count)
    }

    @Test("Content filter save errors have Korean and English translations")
    func contentFilterSaveErrorsAreLocalized() {
        #expect(
            CalendarLocalization.text("calendar.error.contentFilter", locale: .korean)
                != "calendar.error.contentFilter"
        )
        #expect(
            CalendarLocalization.text("calendar.error.contentFilter", locale: .english)
                != "calendar.error.contentFilter"
        )
        #expect(
            teamLocalized("team.common.contentFilterError", locale: .korean)
                != "team.common.contentFilterError"
        )
        #expect(
            teamLocalized("team.common.contentFilterError", locale: .english)
                != "team.common.contentFilterError"
        )
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

private struct BundledBannedWordsResource: Decodable {
    let schemaVersion: Int
    let words: [String]
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
