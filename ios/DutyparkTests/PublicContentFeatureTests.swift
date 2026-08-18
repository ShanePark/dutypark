import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite("Native public content", .serialized)
struct PublicContentFeatureTests {
    @Test("Guide and release note contracts decode the public JSON shape")
    func decodesContracts() throws {
        let guide = try JSONDecoder().decode(PublicGuideContent.self, from: Data(#"""
        {
          "schemaVersion":1,"contentVersion":"2026-08-15","locale":"ko",
          "title":"이용 안내","description":"주요 기능 안내","footer":"문의해 주세요.",
          "actions":{"expandAll":"모두 펼치기","collapseAll":"모두 접기"},
          "sections":[{"id":"calendar","title":"내 달력","summary":"일정을 관리합니다.",
            "icon":"calendar","tone":"success",
            "cards":[{"id":"schedule","title":"일정 관리","icon":"plus","tone":"accent",
              "items":["일정을 추가합니다."]}]}]
        }
        """#.utf8))

        #expect(guide.locale == "ko")
        #expect(guide.actions.expandAll == "모두 펼치기")
        #expect(guide.sections.first?.cards.first?.items == ["일정을 추가합니다."])
        #expect(guide.sections.first?.icon == "calendar")
        #expect(guide.sections.first?.tone == "success")
        #expect(guide.sections.first?.cards.first?.icon == "plus")
        #expect(guide.sections.first?.cards.first?.tone == "accent")

        let page = try JSONDecoder().decode(PublicReleaseNotesPage.self, from: Data(#"""
        {
          "schemaVersion":1,"contentVersion":"2026-08-15","locale":"ko",
          "labels":{"title":"변경사항","count":"총 {count}개의 변경사항","loadMore":"더 보기",
            "latest":"최신","pr":"PR #{number}","areas":"영역",
            "categoryLabels":{"feature":"기능"},"areaLabels":{"guide":"이용 안내"}},
          "items":[{"id":"pr-403","version":"1.0.0","date":"2026-08-15","pr":403,
            "url":"https://github.com/shanepark/dutypark/pull/403","category":"feature","areas":["guide"],
            "title":"네이티브 앱","summary":"앱을 출시합니다.","changes":["SwiftUI 화면을 제공합니다."]}],
          "page":0,"size":5,"totalElements":6,"totalPages":2,"hasNext":true
        }
        """#.utf8))

        #expect(page.labels.categoryLabels["feature"] == "기능")
        #expect(page.labels.countText(6) == "총 6개의 변경사항")
        #expect(page.labels.prText(403) == "PR #403")
        #expect(page.items.first?.pr == 403)
        #expect(page.hasNext)
    }

    @Test("Guide locale follows the explicit app language and supported device fallback")
    func resolvesLocale() {
        #expect(PublicContentLocaleResolver.locale(languageCode: "ko") == "ko")
        #expect(PublicContentLocaleResolver.locale(languageCode: "en") == "en")
        #expect(PublicContentLocaleResolver.locale(languageCode: "fr-FR") == "en")
        #expect(PublicContentLocaleResolver.locale(
            languageCode: "",
            preferredLanguages: ["ko-KR"]
        ) == "ko")
    }

    @Test("Service requests public endpoints with locale and release pagination")
    func serviceRequestContract() async throws {
        let recorder = PublicContentRequestRecorder()
        PublicContentURLProtocol.handler = { request in
            recorder.record(request)
            if request.url?.path == "/api/public-content/guide" {
                return try publicContentResponse(request, body: #"""
                {"schemaVersion":1,"contentVersion":"1","locale":"ko","title":"이용 안내",
                 "description":"설명","footer":"문의",
                 "actions":{"expandAll":"모두 펼치기","collapseAll":"모두 접기"},"sections":[]}
                """#)
            }
            return try publicContentResponse(request, body: #"""
            {"schemaVersion":1,"contentVersion":"1","locale":"en",
             "labels":{"title":"Release notes","count":"{count} changes","loadMore":"Load more",
               "latest":"Latest","pr":"PR #{number}","areas":"Areas","categoryLabels":{},"areaLabels":{}},
             "items":[],"page":2,"size":5,"totalElements":0,"totalPages":0,"hasNext":false}
            """#)
        }
        defer { PublicContentURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicContentURLProtocol.self]
        let service = PublicContentService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))

        let guide = try await service.guide(locale: "ko")
        let page = try await service.releaseNotes(locale: "en", page: 2, size: 5)

        #expect(guide.title == "이용 안내")
        #expect(page.page == 2)
        let requests = recorder.requests
        #expect(requests.count == 2)
        #expect(requests[0].url?.path == "/api/public-content/guide")
        #expect(Self.query(requests[0]) == ["locale": "ko"])
        #expect(requests[1].url?.path == "/api/public-content/release-notes")
        #expect(Self.query(requests[1]) == ["locale": "en", "page": "2", "size": "5"])
    }

    @Test("Service rejects unsupported public content schema versions")
    func rejectsUnsupportedSchemaVersion() async {
        PublicContentURLProtocol.handler = { request in
            try publicContentResponse(request, body: #"""
            {"schemaVersion":2,"contentVersion":"2","locale":"en","title":"Guide",
             "description":"Description","footer":"Footer",
             "actions":{"expandAll":"Expand all","collapseAll":"Collapse all"},"sections":[]}
            """#)
        }
        defer { PublicContentURLProtocol.handler = nil }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [PublicContentURLProtocol.self]
        let service = PublicContentService(client: APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        ))

        do {
            _ = try await service.guide(locale: "en")
            Issue.record("Unsupported schema version should fail")
        } catch let error as APIError {
            #expect(error == .decoding)
        } catch {
            Issue.record("Expected APIError.decoding, received \(error)")
        }
    }

    @Test("Guide view model exposes loading failure and retry success")
    func guideRetry() async {
        let service = PublicContentServiceMock()
        service.guideResults = [
            .failure(APIError.transport),
            .success(Self.guide(locale: "ko")),
        ]
        let model = PublicGuideViewModel(service: service)

        await model.load(locale: "ko")
        #expect(model.content == nil)
        #expect(model.hasError)

        await model.load(locale: "ko")
        #expect(model.content?.title == "이용 안내")
        #expect(!model.hasError)
        #expect(service.guideLocales == ["ko", "ko"])
    }

    @Test("Guide clears a previous language but retains same-language content during refresh failure")
    func guideLocaleRefreshPolicy() async {
        let service = PublicContentServiceMock()
        service.guideResults = [
            .success(Self.guide(locale: "en")),
            .failure(APIError.transport),
            .success(Self.guide(locale: "en")),
            .failure(APIError.transport),
        ]
        let model = PublicGuideViewModel(service: service)

        await model.load(locale: "en")
        await model.load(locale: "ko")
        #expect(model.content == nil)
        #expect(model.loadedLocale == nil)

        await model.load(locale: "en")
        await model.load(locale: "en")
        #expect(model.content?.locale == "en")
        #expect(model.loadedLocale == "en")
    }

    @Test("Release note view model appends the next page once")
    func releasePagination() async {
        let service = PublicContentServiceMock()
        service.releaseResults = [
            .success(Self.releasePage(page: 0, hasNext: true, id: "pr-2")),
            .success(Self.releasePage(page: 1, hasNext: false, id: "pr-1")),
        ]
        let model = PublicReleaseNotesViewModel(service: service)

        await model.load(locale: "en")
        await model.loadNextPage()
        await model.loadNextPage()

        #expect(model.items.map(\.id) == ["pr-2", "pr-1"])
        #expect(!model.hasNext)
        #expect(service.releaseRequests == [
            .init(locale: "en", page: 0, size: 5),
            .init(locale: "en", page: 1, size: 5),
        ])
    }

    @Test("Release notes restart from page zero when paginated content versions differ")
    func releaseVersionMismatchReloadsFirstPage() async {
        let service = PublicContentServiceMock()
        service.releaseResults = [
            .success(Self.releasePage(page: 0, hasNext: true, id: "old-2", contentVersion: "1")),
            .success(Self.releasePage(page: 1, hasNext: false, id: "new-1", contentVersion: "2")),
            .success(Self.releasePage(page: 0, hasNext: false, id: "fresh-2", contentVersion: "2")),
        ]
        let model = PublicReleaseNotesViewModel(service: service)

        await model.load(locale: "en")
        await model.loadNextPage()

        #expect(model.items.map(\.id) == ["fresh-2"])
        #expect(service.releaseRequests.map(\.page) == [0, 1, 0])
    }

    @Test("Release notes clear a previous locale and retain same-locale content on refresh failure")
    func releaseLocaleRefreshPolicy() async {
        let service = PublicContentServiceMock()
        service.releaseResults = [
            .success(Self.releasePage(page: 0, hasNext: false, id: "english", locale: "en")),
            .failure(APIError.transport),
            .success(Self.releasePage(page: 0, hasNext: false, id: "english-2", locale: "en")),
            .failure(APIError.transport),
        ]
        let model = PublicReleaseNotesViewModel(service: service)

        await model.load(locale: "en")
        await model.load(locale: "ko")
        #expect(model.items.isEmpty)
        #expect(model.loadedLocale == nil)

        await model.load(locale: "en")
        await model.load(locale: "en")
        #expect(model.items.map(\.id) == ["english-2"])
        #expect(model.loadedLocale == "en")
    }

    @Test("Server identifiers map to native symbols and semantic tones")
    func nativePresentationMapping() {
        let section = PublicContentPresentation.guideVisual(icon: "calendar", tone: "success")
        #expect(section.symbol == "calendar")
        #expect(section.tone == .success)
        let card = PublicContentPresentation.guideVisual(icon: "sparkles", tone: "accentLight")
        #expect(card.symbol == "sparkles")
        #expect(card.tone == .accentLight)
        #expect(PublicContentPresentation.releaseCategory("security").symbol == "lock.shield")
        #expect(PublicContentPresentation.releaseCategory("fix").tone == .danger)
        #expect(PublicContentPresentation.releaseCategory("future").tone == .neutral)
    }

    /// The shared vocabulary is the only thing keeping the iOS and web guides visually aligned,
    /// so every key of both closed sets is asserted here rather than a representative sample.
    @Test("Every guide vocabulary key resolves to its own native symbol and tone")
    func guideVocabularyIsComplete() {
        let symbols: [String: String] = [
            "home": "house.fill",
            "calendar": "calendar",
            "calendarCheck": "calendar.badge.clock",
            "building": "building.2.fill",
            "settings": "gearshape.fill",
            "users": "person.2.fill",
            "personAdd": "person.badge.plus",
            "userCog": "person.crop.circle.badge.checkmark",
            "pencil": "pencil",
            "spreadsheet": "tablecells",
            "plus": "plus.circle.fill",
            "sparkles": "sparkles",
            "eye": "eye.fill",
            "checklist": "checklist",
            "search": "magnifyingglass",
            "palette": "paintpalette.fill",
            "sun": "sun.max.fill",
            "bell": "bell.badge.fill",
            "pin": "pin.fill",
            "trash": "trash.fill",
            "camera": "camera.fill",
            "shield": "shield.checkered",
            "phone": "iphone",
            "link": "link",
            "lock": "lock.fill",
        ]
        #expect(symbols.count == 25)
        for (key, expected) in symbols {
            let resolved = PublicContentPresentation.symbol(icon: key)
            #expect(resolved == expected)
            #expect(resolved != PublicContentPresentation.fallbackSymbol)
        }
        #expect(Set(symbols.values).count == symbols.count)

        let tones: [String: PublicContentTone] = [
            "accent": .accent,
            "accentLight": .accentLight,
            "success": .success,
            "warning": .warning,
            "danger": .danger,
            "neutral": .neutral,
            "muted": .muted,
        ]
        #expect(tones.count == 7)
        for (key, expected) in tones {
            #expect(PublicContentPresentation.tone(key) == expected)
        }
    }

    @Test("Unknown guide vocabulary keys fall back to the documented symbol and tone")
    func guideVocabularyFallback() {
        let unknown = PublicContentPresentation.guideVisual(icon: "rocket", tone: "electric")
        #expect(unknown.symbol == "book.closed.fill")
        #expect(unknown.tone == .neutral)
        #expect(PublicContentPresentation.symbol(icon: "Home") == "book.closed.fill")
        #expect(PublicContentPresentation.tone("Accent") == .neutral)
    }

    private static func guide(locale: String) -> PublicGuideContent {
        PublicGuideContent(
            schemaVersion: 1,
            contentVersion: "1",
            locale: locale,
            title: locale == "ko" ? "이용 안내" : "Guide",
            description: "Description",
            footer: "Footer",
            actions: .init(expandAll: "Expand all", collapseAll: "Collapse all"),
            sections: []
        )
    }

    private static func releasePage(
        page: Int,
        hasNext: Bool,
        id: String,
        contentVersion: String = "1",
        locale: String = "en"
    ) -> PublicReleaseNotesPage {
        PublicReleaseNotesPage(
            schemaVersion: 1,
            contentVersion: contentVersion,
            locale: locale,
            labels: .init(
                title: "Release notes",
                count: "{count} changes",
                loadMore: "Load more",
                latest: "Latest",
                pr: "PR #{number}",
                areas: "Areas",
                categoryLabels: ["feature": "Feature"],
                areaLabels: ["guide": "Guide"]
            ),
            items: [
                .init(
                    id: id,
                    version: "1.0.0",
                    date: "2026-08-15",
                    pr: 1,
                    url: "https://github.com/shanepark/dutypark/pull/1",
                    category: "feature",
                    areas: ["guide"],
                    title: id,
                    summary: "Summary",
                    changes: ["Change"]
                ),
            ],
            page: page,
            size: 5,
            totalElements: 2,
            totalPages: 2,
            hasNext: hasNext
        )
    }

    private static func query(_ request: URLRequest) -> [String: String] {
        guard let url = request.url,
              let items = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        else { return [:] }
        return Dictionary(uniqueKeysWithValues: items.map { ($0.name, $0.value ?? "") })
    }
}

private final class PublicContentServiceMock: PublicContentServicing, @unchecked Sendable {
    struct Request: Equatable {
        let locale: String
        let page: Int
        let size: Int
    }

    var guideResults: [Result<PublicGuideContent, Error>] = []
    var releaseResults: [Result<PublicReleaseNotesPage, Error>] = []
    private(set) var guideLocales: [String] = []
    private(set) var releaseRequests: [Request] = []

    func guide(locale: String) async throws -> PublicGuideContent {
        guideLocales.append(locale)
        return try guideResults.removeFirst().get()
    }

    func releaseNotes(locale: String, page: Int, size: Int) async throws -> PublicReleaseNotesPage {
        releaseRequests.append(.init(locale: locale, page: page, size: size))
        return try releaseResults.removeFirst().get()
    }
}

private final class PublicContentURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        do {
            let handler = try Self.handler.unwrap()
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private final class PublicContentRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var values: [URLRequest] = []

    var requests: [URLRequest] {
        lock.withLock { values }
    }

    func record(_ request: URLRequest) {
        lock.withLock { values.append(request) }
    }
}

nonisolated private func publicContentResponse(
    _ request: URLRequest,
    body: String
) throws -> (HTTPURLResponse, Data) {
    let url = try request.url.unwrap()
    guard let response = HTTPURLResponse(
        url: url,
        statusCode: 200,
        httpVersion: nil,
        headerFields: ["Content-Type": "application/json"]
    ) else { throw PublicContentTestError.missingValue }
    return (response, Data(body.utf8))
}

private enum PublicContentTestError: Error {
    case missingValue
}

private extension Optional {
    func unwrap() throws -> Wrapped {
        guard let self else { throw PublicContentTestError.missingValue }
        return self
    }
}
