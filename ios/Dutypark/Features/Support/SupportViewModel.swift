import Combine
import Foundation

/// The two sections of the support screen. Guests only ever see `form`: the history
/// needs a session, and the signed-out screen stays the public contact page App Review
/// 1.2 asks for.
nonisolated enum SupportTab: String, Hashable, CaseIterable, Identifiable, Sendable {
    case form
    case history

    var id: String { rawValue }

    var titleKey: String {
        switch self {
        case .form: "support.tab.form"
        case .history: "support.tab.history"
        }
    }
}

@MainActor
final class SupportViewModel: ObservableObject {
    static let inquiryPageSize = 10

    @Published var email: String
    @Published var subject = ""
    @Published var content = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var didSubmit = false
    @Published var errorKey: String?
    @Published var selectedTab: SupportTab
    @Published private(set) var inquiries: [MyInquiryDTO] = []
    @Published private(set) var isLoadingInquiries = false
    @Published private(set) var isLoadingMoreInquiries = false
    @Published private(set) var inquiryLoadFailed = false

    let isSignedIn: Bool
    private let repository: any SupportRepository
    private var loadedInquiryPage = 0
    private var totalInquiryPages = 0
    private var hasLoadedInquiries = false

    init(
        prefilledEmail: String? = nil,
        isSignedIn: Bool = false,
        initialTab: SupportTab = .form,
        repository: any SupportRepository = LiveSupportRepository()
    ) {
        self.email = prefilledEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.isSignedIn = isSignedIn
        self.selectedTab = isSignedIn ? initialTab : .form
        self.repository = repository
    }

    var showsTabs: Bool {
        isSignedIn
    }

    /// Members read the answer in the app, so the form must not promise an e-mail that
    /// the server has no way to send.
    var formDescriptionKey: String {
        isSignedIn ? "support.form.description.member" : "support.form.description"
    }

    var successMessageKey: String {
        isSignedIn ? "support.success.message.member" : "support.success.message"
    }

    var showsSignInHint: Bool {
        !isSignedIn
    }

    var hasMoreInquiries: Bool {
        loadedInquiryPage < totalInquiryPages - 1
    }

    var canSubmit: Bool {
        !isSubmitting
            && !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    func submit() async {
        guard !isSubmitting else { return }
        let trimmedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedSubject = subject.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)

        if let validationKey = Self.validationErrorKey(email: trimmedEmail, content: trimmedContent) {
            errorKey = validationKey
            return
        }

        errorKey = nil
        isSubmitting = true
        defer { isSubmitting = false }

        do {
            try await repository.submitInquiry(
                CreateInquiryRequest(
                    email: trimmedEmail,
                    subject: trimmedSubject.isEmpty
                        ? nil
                        : Self.limited(
                            trimmedSubject,
                            maximumUTF16Length: CreateInquiryRequest.subjectMaximumLength
                        ),
                    content: Self.limited(
                        trimmedContent,
                        maximumUTF16Length: CreateInquiryRequest.contentMaximumLength
                    )
                ),
                authenticated: isSignedIn
            )
            subject = ""
            content = ""
            didSubmit = true
            // The list on screen no longer contains every inquiry, so the next visit to
            // the history tab has to fetch the first page again.
            hasLoadedInquiries = false
        } catch {
            errorKey = Self.errorKey(for: error)
        }
    }

    func loadInquiriesIfNeeded() async {
        guard !hasLoadedInquiries else { return }
        await loadInquiries()
    }

    func loadInquiries() async {
        guard isSignedIn, !isLoadingInquiries else { return }
#if DEBUG
        if isUITesting {
            loadUITestingFixture()
            return
        }
#endif
        isLoadingInquiries = true
        defer { isLoadingInquiries = false }

        do {
            let page = try await repository.fetchMyInquiries(page: 0, size: Self.inquiryPageSize)
            inquiries = page.content
            loadedInquiryPage = page.number
            totalInquiryPages = page.totalPages
            inquiryLoadFailed = false
            hasLoadedInquiries = true
        } catch {
            inquiryLoadFailed = true
        }
    }

    func loadMoreInquiries() async {
        guard hasMoreInquiries, !isLoadingInquiries, !isLoadingMoreInquiries else { return }
        isLoadingMoreInquiries = true
        defer { isLoadingMoreInquiries = false }

        do {
            let page = try await repository.fetchMyInquiries(
                page: loadedInquiryPage + 1,
                size: Self.inquiryPageSize
            )
            inquiries.append(contentsOf: page.content.filter { next in
                !inquiries.contains(where: { $0.id == next.id })
            })
            loadedInquiryPage = page.number
            totalInquiryPages = page.totalPages
            inquiryLoadFailed = false
        } catch {
            inquiryLoadFailed = true
        }
    }

    /// The confirmation replaces the form, so writing again has to restore it without
    /// losing the reply address the sender already confirmed.
    func startNewInquiry() {
        didSubmit = false
        errorKey = nil
    }

    nonisolated static func validationErrorKey(email: String, content: String) -> String? {
        if email.isEmpty { return "support.error.emailRequired" }
        if !isValidEmail(email) { return "support.error.emailInvalid" }
        if content.isEmpty { return "support.error.contentRequired" }
        return nil
    }

    /// Mirrors the server's `@Email` acceptance closely enough to catch typos locally;
    /// the server stays the authority.
    nonisolated static func isValidEmail(_ value: String) -> Bool {
        guard value.count <= 255,
              !value.contains(where: \.isWhitespace)
        else { return false }
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        guard parts.count == 2 else { return false }
        let local = parts[0]
        let domain = parts[1]
        guard !local.isEmpty, !domain.isEmpty, domain.contains(".") else { return false }
        guard !domain.hasPrefix("."), !domain.hasSuffix("."), !domain.contains("..") else {
            return false
        }
        return true
    }

    /// Jakarta `@Size` measures a Java string in UTF-16 code units. Preserve complete
    /// Swift characters while keeping the encoded value within that same server limit.
    nonisolated static func limited(_ value: String, maximumUTF16Length: Int) -> String {
        guard value.utf16.count > maximumUTF16Length else { return value }

        var result = ""
        var usedUTF16Length = 0
        for character in value {
            let characterUTF16Length = String(character).utf16.count
            guard usedUTF16Length + characterUTF16Length <= maximumUTF16Length else { break }
            result.append(character)
            usedUTF16Length += characterUTF16Length
        }
        return result
    }

    nonisolated static func errorKey(for error: Error) -> String {
        guard let apiError = error as? APIError else { return "support.error.submit" }
        return switch apiError {
        case .server(status: 429, _), .serverWithDetails(status: 429, _, _):
            "support.error.rateLimit"
        default:
            "support.error.submit"
        }
    }

#if DEBUG
    private var isUITesting: Bool {
        ProcessInfo.processInfo.arguments.contains("-ui-testing-authenticated")
    }

    /// Authenticated UI testing never reaches the network, so the history tab has to be
    /// served locally. One answered and one waiting inquiry cover every badge and both
    /// detail states.
    private func loadUITestingFixture() {
        inquiries = [
            MyInquiryDTO(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000301")!,
                email: "test@duty.park",
                subject: "달력이 열리지 않아요",
                content: "친구 달력을 열면 잠시 후 화면이 닫힙니다. 확인 부탁드립니다.",
                status: .closed,
                createdAt: LocalDateTimeValue(rawValue: "2026-08-14T10:12:00"),
                answer: "확인 후 수정 배포했습니다. 최신 버전으로 업데이트해 주세요. 이용에 불편을 드려 죄송합니다.",
                answeredAt: LocalDateTimeValue(rawValue: "2026-08-15T09:03:00")
            ),
            MyInquiryDTO(
                id: UUID(uuidString: "00000000-0000-0000-0000-000000000302")!,
                email: "test@duty.park",
                subject: nil,
                content: "팀 근무표를 내보내는 기능도 있으면 좋겠습니다.",
                status: .open,
                createdAt: LocalDateTimeValue(rawValue: "2026-08-17T21:40:00"),
                answer: nil,
                answeredAt: nil
            )
        ]
        loadedInquiryPage = 0
        totalInquiryPages = 1
        inquiryLoadFailed = false
        hasLoadedInquiries = true
    }
#endif
}

nonisolated enum MyInquiryPresentation {
    static func subjectText(
        _ inquiry: MyInquiryDTO,
        locale: Locale? = nil
    ) -> String {
        let trimmed = inquiry.subject?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty
            ? SupportLocalization.text("support.history.subjectFallback", locale: locale)
            : trimmed
    }

    static func statusKey(_ status: InquiryStatus) -> String {
        switch status {
        case .open: "support.history.status.open"
        case .closed: "support.history.status.closed"
        }
    }

    static func answerStateKey(_ inquiry: MyInquiryDTO) -> String {
        inquiry.hasAnswer ? "support.history.answered" : "support.history.awaiting"
    }

    /// The server sends a `LocalDateTime`, so the value is parsed without assuming a
    /// time zone and rendered as a plain calendar date.
    static func date(
        _ value: LocalDateTimeValue,
        locale: Locale = AppLocalization.locale
    ) -> String {
        let parser = DateFormatter()
        parser.calendar = Calendar(identifier: .gregorian)
        parser.locale = Locale(identifier: "en_US_POSIX")
        parser.timeZone = .current
        parser.dateFormat = value.rawValue.contains(".")
            ? "yyyy-MM-dd'T'HH:mm:ss.SSSSSS"
            : "yyyy-MM-dd'T'HH:mm:ss"
        guard let date = parser.date(from: value.rawValue) else { return value.rawValue }

        let supportedLocale = AppLocalization.supportedLocale(
            languageCode: locale.identifier,
            preferredLanguages: []
        )
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = supportedLocale
        formatter.timeZone = .current
        formatter.dateFormat = supportedLocale.identifier == "ko" ? "yyyy.MM.dd" : "MMM d, yyyy"
        return formatter.string(from: date)
    }
}
