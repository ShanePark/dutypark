import Foundation
import Testing
@testable import Dutypark

@MainActor
struct PaginationMergeTests {
    @Test
    func notificationPagesKeepExistingRowsAndIncomingDuplicateOrder() async throws {
        let first = try [notification(1, title: "original"), notification(2, title: "second")]
        let next = try [
            notification(2, title: "ignored replacement"),
            notification(3, title: "new first"),
            notification(3, title: "new duplicate"),
            notification(4, title: "new last"),
        ]
        let api = PaginationNotificationAPI(pages: [page(first, number: 0), page(next, number: 1)])
        let store = NotificationStore(api: api)

        await store.refresh()
        let loaded = await store.loadMore(emitsHaptic: false)

        #expect(loaded)
        #expect(store.notifications == first + Array(next.dropFirst()))
        #expect(!store.hasMore)
        #expect(!store.isLoadingMore)
        let loadedAgain = await store.loadMore(emitsHaptic: false)
        #expect(!loadedAgain)
    }

    @Test
    func inquiryPagesKeepExistingRowsAndIncomingDuplicateOrder() async {
        let first = [inquiry(1, title: "original"), inquiry(2, title: "second")]
        let next = [
            inquiry(2, title: "ignored replacement"),
            inquiry(3, title: "new first"),
            inquiry(3, title: "new duplicate"),
            inquiry(4, title: "new last"),
        ]
        let repository = PaginationSupportRepository(inquiries: [page(first, number: 0), page(next, number: 1)])
        let model = SupportViewModel(isSignedIn: true, repository: repository)

        await model.loadInquiries()
        await model.loadMoreInquiries()

        #expect(model.inquiries == first + Array(next.dropFirst()))
        #expect(!model.hasMoreInquiries)
        #expect(!model.isLoadingMoreInquiries)
    }

    @Test
    func reportPagesKeepExistingRowsAndIncomingDuplicateOrder() async {
        let first = [report(1, name: "original"), report(2, name: "second")]
        let next = [
            report(2, name: "ignored replacement"),
            report(3, name: "new first"),
            report(3, name: "new duplicate"),
            report(4, name: "new last"),
        ]
        let repository = PaginationSupportRepository(reports: [page(first, number: 0), page(next, number: 1)])
        let model = SupportViewModel(isSignedIn: true, repository: repository)

        await model.loadReports()
        await model.loadMoreReports()

        #expect(model.reports == first + Array(next.dropFirst()))
        #expect(!model.hasMoreReports)
        #expect(!model.isLoadingMoreReports)
    }

    private func id(_ number: Int) -> UUID {
        UUID(uuidString: String(format: "00000000-0000-4000-8000-%012d", number))!
    }

    private func notification(_ number: Int, title: String) throws -> NotificationDTO {
        NotificationDTO(
            id: id(number),
            type: .inquiryAnswered,
            referenceType: nil,
            referenceId: title,
            actorId: nil,
            payload: try JSONDecoder().decode(NotificationPayloadDTO.self, from: Data("{}".utf8)),
            isRead: false,
            createdAt: LocalDateTimeValue(rawValue: "2026-09-12T10:00:00")
        )
    }

    private func inquiry(_ number: Int, title: String) -> MyInquiryDTO {
        MyInquiryDTO(
            id: id(number), email: nil, subject: title, content: "content", status: .open,
            createdAt: LocalDateTimeValue(rawValue: "2026-09-12T10:00:00"),
            answer: nil, answeredAt: nil
        )
    }

    private func report(_ number: Int, name: String) -> MyReportDTO {
        MyReportDTO(
            id: id(number), targetType: .member, reportedMemberName: name,
            reason: .spam, detail: nil, status: .open,
            createdAt: LocalDateTimeValue(rawValue: "2026-09-12T10:00:00"), resolvedAt: nil
        )
    }

    private func page<Element: Codable & Equatable & Sendable>(
        _ content: [Element], number: Int
    ) -> PageResponse<Element> {
        PageResponse(
            content: content, totalPages: 2, totalElements: 6, last: number == 1,
            first: number == 0, size: 4, number: number,
            numberOfElements: content.count, empty: content.isEmpty
        )
    }
}

private struct PaginationNotificationAPI: NotificationAPIProtocol {
    let pages: [PageResponse<NotificationDTO>]

    func notifications(page: Int, size: Int) async throws -> PageResponse<NotificationDTO> { pages[page] }
    func unreadNotifications() async throws -> [NotificationDTO] { [] }
    func count() async throws -> NotificationCountDTO { NotificationCountDTO(unreadCount: 0, totalCount: 6) }
    func friendRequestCount() async throws -> Int { 0 }
    func markAsRead(id: NotificationID) async throws -> NotificationDTO { throw APIError.invalidResponse }
    func markAllAsRead() async throws -> Int { throw APIError.invalidResponse }
    func delete(id: NotificationID) async throws { throw APIError.invalidResponse }
    func deleteAllRead() async throws -> Int { throw APIError.invalidResponse }
}
private struct PaginationSupportRepository: SupportRepository {
    var inquiries: [PageResponse<MyInquiryDTO>] = []
    var reports: [PageResponse<MyReportDTO>] = []

    func fetchMyInquiries(page: Int, size: Int) async throws -> PageResponse<MyInquiryDTO> { inquiries[page] }
    func fetchMyReports(page: Int, size: Int) async throws -> PageResponse<MyReportDTO> { reports[page] }
    func submitInquiry(_ request: CreateInquiryRequest, authenticated: Bool) async throws { throw APIError.invalidResponse }
    func cancelReport(id: UUID) async throws -> MyReportDTO { throw APIError.invalidResponse }
}
