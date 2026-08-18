import Foundation
import Testing
@testable import Dutypark

@MainActor
struct SupportFeatureTests {
    @Test
    func theAccountEmailIsPrefilledAndTrimmed() {
        let model = SupportViewModel(prefilledEmail: "  member@dutypark.dev  ", repository: SupportRepositorySpy())
        #expect(model.email == "member@dutypark.dev")
        #expect(SupportViewModel(prefilledEmail: nil, repository: SupportRepositorySpy()).email.isEmpty)
    }

    @Test
    func submissionRequiresAnEmailAddress() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(prefilledEmail: "   ", repository: repository)
        model.content = "The other member keeps posting spam."

        await model.submit()

        #expect(model.errorKey == "support.error.emailRequired")
        #expect(repository.submissions.isEmpty)
        #expect(!model.didSubmit)
    }

    @Test
    func submissionRejectsAMalformedEmailAddress() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(prefilledEmail: "member@dutypark", repository: repository)
        model.content = "The other member keeps posting spam."

        await model.submit()

        #expect(model.errorKey == "support.error.emailInvalid")
        #expect(repository.submissions.isEmpty)

        for rejected in ["member", "@dutypark.dev", "member@", "mem ber@dutypark.dev", "member@.dev", "member@dutypark..dev"] {
            #expect(!SupportViewModel.isValidEmail(rejected), "Accepted \(rejected)")
        }
        for accepted in ["member@dutypark.dev", "first.last+tag@sub.dutypark.co.kr"] {
            #expect(SupportViewModel.isValidEmail(accepted), "Rejected \(accepted)")
        }
    }

    @Test
    func submissionRequiresContent() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(prefilledEmail: "member@dutypark.dev", repository: repository)
        model.subject = "Report"
        model.content = "   \n  "

        await model.submit()

        #expect(model.errorKey == "support.error.contentRequired")
        #expect(repository.submissions.isEmpty)
    }

    @Test
    func aSuccessfulSubmissionSendsTheTrimmedInquiryAndShowsTheConfirmation() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(prefilledEmail: "member@dutypark.dev", repository: repository)
        model.subject = "  Reporting a user  "
        model.content = "  The other member keeps posting spam.  "

        await model.submit()

        #expect(repository.submissions == [
            CreateInquiryRequest(
                email: "member@dutypark.dev",
                subject: "Reporting a user",
                content: "The other member keeps posting spam."
            )
        ])
        #expect(model.didSubmit)
        #expect(model.errorKey == nil)
        #expect(!model.isSubmitting)
        // The address is kept so a follow-up inquiry does not have to be retyped.
        #expect(model.email == "member@dutypark.dev")
        #expect(model.subject.isEmpty)
        #expect(model.content.isEmpty)

        model.startNewInquiry()
        #expect(!model.didSubmit)
    }

    @Test
    func anEmptySubjectIsOmittedFromTheRequest() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(prefilledEmail: "member@dutypark.dev", repository: repository)
        model.content = "Please review this account."

        await model.submit()

        #expect(repository.submissions.first?.subject == nil)
    }

    @Test
    func aRateLimitedSubmissionAsksTheSenderToRetryLater() async {
        let repository = SupportRepositorySpy(failure: .server(status: 429, code: "inquiry.rateLimit.exceeded"))
        let model = SupportViewModel(prefilledEmail: "member@dutypark.dev", repository: repository)
        model.content = "Please review this account."

        await model.submit()

        #expect(model.errorKey == "support.error.rateLimit")
        #expect(!model.didSubmit)
        #expect(!model.isSubmitting)
    }

    @Test
    func anyOtherFailureKeepsTheFormWithAGenericMessage() async {
        let repository = SupportRepositorySpy(failure: .transport)
        let model = SupportViewModel(prefilledEmail: "member@dutypark.dev", repository: repository)
        model.content = "Please review this account."

        await model.submit()

        #expect(model.errorKey == "support.error.submit")
        #expect(!model.didSubmit)
        #expect(model.content == "Please review this account.")
    }

    @Test
    func longFieldsAreCappedToTheServerLimits() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(prefilledEmail: "member@dutypark.dev", repository: repository)
        model.subject = String(repeating: "s", count: 140)
        model.content = String(repeating: "c", count: 2400)

        await model.submit()

        #expect(repository.submissions.first?.subject?.count == CreateInquiryRequest.subjectMaximumLength)
        #expect(repository.submissions.first?.content.count == CreateInquiryRequest.contentMaximumLength)
    }

    @Test
    func theSupportCatalogIsFullyTranslated() throws {
        let catalogURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Support/Support.xcstrings")
        let root = try #require(
            JSONSerialization.jsonObject(with: Data(contentsOf: catalogURL)) as? [String: Any]
        )
        let strings = try #require(root["strings"] as? [String: Any])
        #expect(!strings.isEmpty)

        for (key, rawEntry) in strings {
            let entry = try #require(rawEntry as? [String: Any], "Invalid entry \(key)")
            let localizations = try #require(entry["localizations"] as? [String: Any], "No localizations for \(key)")
            for language in ["en", "ko"] {
                let localization = try #require(localizations[language] as? [String: Any], "Missing \(language) for \(key)")
                let stringUnit = try #require(localization["stringUnit"] as? [String: Any])
                #expect(stringUnit["state"] as? String == "translated", "Untranslated \(language) value for \(key)")
                let value = try #require(stringUnit["value"] as? String)
                #expect(!value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, "Empty \(language) value for \(key)")
            }
        }
    }

    @Test
    func theSupportCatalogResolvesInEveryLocale() throws {
        for locale in ["en", "ko"] {
            let url = try #require(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            for key in [
                "support.title",
                "support.guide.report.title",
                "support.guide.block.title",
                "support.guide.policy.description",
                "support.form.submit",
                "support.success.title",
                "support.error.rateLimit",
                "support.guest.entry"
            ] {
                #expect(
                    bundle.localizedString(forKey: key, value: key, table: "Support") != key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }
}

private final class SupportRepositorySpy: SupportRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let failure: APIError?
    private var storedSubmissions: [CreateInquiryRequest] = []

    init(failure: APIError? = nil) {
        self.failure = failure
    }

    var submissions: [CreateInquiryRequest] {
        lock.withLock { storedSubmissions }
    }

    func submitInquiry(_ request: CreateInquiryRequest) async throws {
        lock.withLock { storedSubmissions.append(request) }
        if let failure { throw failure }
    }
}
