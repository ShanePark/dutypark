import Combine
import Foundation

@MainActor
final class SupportViewModel: ObservableObject {
    @Published var email: String
    @Published var subject = ""
    @Published var content = ""
    @Published private(set) var isSubmitting = false
    @Published private(set) var didSubmit = false
    @Published var errorKey: String?

    private let repository: any SupportRepository

    init(
        prefilledEmail: String? = nil,
        repository: any SupportRepository = LiveSupportRepository()
    ) {
        self.email = prefilledEmail?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        self.repository = repository
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
                        : String(trimmedSubject.prefix(CreateInquiryRequest.subjectMaximumLength)),
                    content: String(trimmedContent.prefix(CreateInquiryRequest.contentMaximumLength))
                )
            )
            subject = ""
            content = ""
            didSubmit = true
        } catch {
            errorKey = Self.errorKey(for: error)
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

    nonisolated static func errorKey(for error: Error) -> String {
        guard let apiError = error as? APIError else { return "support.error.submit" }
        return switch apiError {
        case .server(status: 429, _), .serverWithDetails(status: 429, _, _):
            "support.error.rateLimit"
        default:
            "support.error.submit"
        }
    }
}
