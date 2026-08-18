import Foundation
import Combine

@MainActor
final class PublicGuideViewModel: ObservableObject {
    @Published private(set) var content: PublicGuideContent?
    @Published private(set) var loadedLocale: String?
    @Published private(set) var isLoading = false
    @Published private(set) var hasError = false

    private let service: any PublicContentServicing
    private var requestID = UUID()

    init(service: any PublicContentServicing = PublicContentService()) {
        self.service = service
    }

    func load(locale: String) async {
        let currentRequestID = UUID()
        requestID = currentRequestID
        if loadedLocale != locale {
            content = nil
            loadedLocale = nil
        }
        isLoading = true
        hasError = false

#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated") {
            content = PublicGuideContent.uiTestingFixture(locale: locale)
            loadedLocale = locale
            isLoading = false
            return
        }
#endif

        do {
            let content = try await service.guide(locale: locale)
            guard requestID == currentRequestID else { return }
            self.content = content
            loadedLocale = locale
            isLoading = false
        } catch is CancellationError {
            guard requestID == currentRequestID else { return }
            isLoading = false
        } catch {
            guard requestID == currentRequestID else { return }
            isLoading = false
            hasError = true
        }
    }
}

@MainActor
final class PublicReleaseNotesViewModel: ObservableObject {
    static let pageSize = 5

    @Published private(set) var labels: PublicReleaseNoteLabels?
    @Published private(set) var items: [PublicReleaseNote] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isLoadingNextPage = false
    @Published private(set) var hasError = false
    @Published private(set) var nextPageHasError = false
    @Published private(set) var hasNext = false
    @Published private(set) var totalElements = 0
    @Published private(set) var loadedLocale: String?

    private let service: any PublicContentServicing
    private var locale = "en"
    private var nextPage = 0
    private var contentVersion: String?
    private var requestID = UUID()

    init(service: any PublicContentServicing = PublicContentService()) {
        self.service = service
    }

    func load(locale: String) async {
        let currentRequestID = UUID()
        requestID = currentRequestID
        if loadedLocale != locale {
            labels = nil
            items = []
            hasNext = false
            totalElements = 0
            contentVersion = nil
            loadedLocale = nil
        }
        self.locale = locale
        isLoading = true
        isLoadingNextPage = false
        hasError = false
        nextPageHasError = false

        do {
            let response = try await service.releaseNotes(
                locale: locale,
                page: 0,
                size: Self.pageSize
            )
            guard requestID == currentRequestID else { return }
            labels = response.labels
            items = response.items
            nextPage = response.page + 1
            hasNext = response.hasNext
            totalElements = response.totalElements
            contentVersion = response.contentVersion
            loadedLocale = locale
            isLoading = false
        } catch is CancellationError {
            guard requestID == currentRequestID else { return }
            isLoading = false
        } catch {
            guard requestID == currentRequestID else { return }
            isLoading = false
            hasError = true
        }
    }

    func loadNextPage() async {
        guard hasNext, !isLoading, !isLoadingNextPage else { return }
        let currentRequestID = requestID
        let requestedLocale = locale
        let requestedPage = nextPage
        isLoadingNextPage = true
        nextPageHasError = false

        do {
            let response = try await service.releaseNotes(
                locale: requestedLocale,
                page: requestedPage,
                size: Self.pageSize
            )
            guard requestID == currentRequestID else { return }
            guard response.contentVersion == contentVersion else {
                isLoadingNextPage = false
                await load(locale: requestedLocale)
                return
            }
            items.append(contentsOf: response.items.filter { incoming in
                !items.contains(where: { $0.id == incoming.id })
            })
            labels = response.labels
            nextPage = response.page + 1
            hasNext = response.hasNext
            totalElements = response.totalElements
            isLoadingNextPage = false
        } catch is CancellationError {
            guard requestID == currentRequestID else { return }
            isLoadingNextPage = false
        } catch {
            guard requestID == currentRequestID else { return }
            isLoadingNextPage = false
            nextPageHasError = true
        }
    }
}
