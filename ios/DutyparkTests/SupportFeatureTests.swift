import Foundation
import Testing
@testable import Dutypark

@MainActor
struct SupportFeatureTests {
    /// A member reads the answer in the app, so the reply address is neither asked for nor
    /// sent; the server records the account e-mail when the account has one. A social
    /// account has none at all, which is why the field cannot simply be prefilled.
    @Test
    func aSignedInMemberIsNeverAskedForAReplyAddress() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(isSignedIn: true, repository: repository)
        #expect(!model.showsEmailField)
        #expect(model.email.isEmpty)

        model.content = "Please keep this inquiry in my history."
        #expect(model.canSubmit)
        await model.submit()

        #expect(repository.submissions == [
            CreateInquiryRequest(
                email: nil,
                subject: nil,
                content: "Please keep this inquiry in my history."
            )
        ])
        #expect(model.errorKey == nil)
        #expect(model.didSubmit)

        #expect(SupportViewModel(isSignedIn: false, repository: SupportRepositorySpy()).showsEmailField)
    }

    @Test
    func submissionRequiresAnEmailAddress() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(repository: repository)
        model.email = "   "
        model.content = "The other member keeps posting spam."

        await model.submit()

        #expect(model.errorKey == "support.error.emailRequired")
        #expect(repository.submissions.isEmpty)
        #expect(!model.didSubmit)
    }

    @Test
    func submissionRejectsAMalformedEmailAddress() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark"
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
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
        model.subject = "Report"
        model.content = "   \n  "

        await model.submit()

        #expect(model.errorKey == "support.error.contentRequired")
        #expect(repository.submissions.isEmpty)
    }

    @Test
    func aSuccessfulSubmissionSendsTheTrimmedInquiryAndShowsTheConfirmation() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
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
    func submissionCarriesWhetherTheSenderMustRemainAuthenticated() async {
        let memberRepository = SupportRepositorySpy()
        let memberModel = SupportViewModel(isSignedIn: true, repository: memberRepository)
        memberModel.content = "Please keep this inquiry in my history."

        await memberModel.submit()

        #expect(memberRepository.authenticatedSubmissions == [true])

        let guestRepository = SupportRepositorySpy()
        let guestModel = SupportViewModel(isSignedIn: false, repository: guestRepository)
        guestModel.email = "guest@dutypark.dev"
        guestModel.content = "Please reply by email."

        await guestModel.submit()

        #expect(guestRepository.authenticatedSubmissions == [false])
    }

    @Test
    func liveMemberSubmissionRefreshesThroughTheProtectedProbeWhileGuestPostsDirectly() async throws {
        let recorder = SupportRequestRecorder()
        defer { SupportURLProtocolStub.handler = nil }
        SupportURLProtocolStub.handler = { request in
            recorder.append(request)
            switch (request.httpMethod, request.url?.path, recorder.count(of: "/api/inquiries/me")) {
            case ("GET", "/api/inquiries/me", 1):
                return Self.httpResponse(
                    request,
                    status: 401,
                    body: #"{"status":401,"code":"auth.required"}"#
                )
            case ("POST", "/api/auth/refresh", _):
                return Self.httpResponse(request, status: 200, body: #"{"expiresIn":3600}"#)
            case ("GET", "/api/inquiries/me", 2):
                return Self.httpResponse(request, status: 200, body: "{}")
            case ("POST", "/api/inquiries", _):
                return Self.httpResponse(request, status: 201, body: #"{"id":"6d2a4c86-1d8b-4c6f-9c1f-6a3a5b2f9c11"}"#)
            default:
                return Self.httpResponse(request, status: 404)
            }
        }

        let repository = LiveSupportRepository(client: Self.supportClient())
        let request = CreateInquiryRequest(
            email: "member@dutypark.dev",
            subject: nil,
            content: "Please keep this inquiry in my history."
        )
        try await repository.submitInquiry(request, authenticated: true)

        #expect(recorder.paths == [
            "/api/inquiries/me",
            "/api/auth/refresh",
            "/api/inquiries/me",
            "/api/inquiries"
        ])

        recorder.removeAll()
        try await repository.submitInquiry(request, authenticated: false)
        #expect(recorder.paths == ["/api/inquiries"])
    }

    @Test
    func anEmptySubjectIsOmittedFromTheRequest() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
        model.content = "Please review this account."

        await model.submit()

        #expect(repository.submissions.first?.subject == nil)
    }

    @Test
    func aRateLimitedSubmissionAsksTheSenderToRetryLater() async {
        let repository = SupportRepositorySpy(failure: .server(status: 429, code: "inquiry.rateLimit.exceeded"))
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
        model.content = "Please review this account."

        await model.submit()

        #expect(model.errorKey == "support.error.rateLimit")
        #expect(!model.didSubmit)
        #expect(!model.isSubmitting)
    }

    @Test
    func anyOtherFailureKeepsTheFormWithAGenericMessage() async {
        let repository = SupportRepositorySpy(failure: .transport)
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
        model.content = "Please review this account."

        await model.submit()

        #expect(model.errorKey == "support.error.submit")
        #expect(!model.didSubmit)
        #expect(model.content == "Please review this account.")
    }

    @Test
    func longFieldsAreCappedToTheServerLimits() async {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
        model.subject = String(repeating: "s", count: 140)
        model.content = String(repeating: "c", count: 2400)

        await model.submit()

        #expect(repository.submissions.first?.subject?.count == CreateInquiryRequest.subjectMaximumLength)
        #expect(repository.submissions.first?.content.count == CreateInquiryRequest.contentMaximumLength)
    }

    @Test
    func nonBMPFieldsAreCappedUsingTheServersUTF16LengthContract() async throws {
        let repository = SupportRepositorySpy()
        let model = SupportViewModel(repository: repository)
        model.email = "member@dutypark.dev"
        model.subject = String(repeating: "😀", count: CreateInquiryRequest.subjectMaximumLength)
        model.content = String(repeating: "😀", count: CreateInquiryRequest.contentMaximumLength)

        await model.submit()

        let request = try #require(repository.submissions.first)
        #expect(request.subject?.utf16.count == CreateInquiryRequest.subjectMaximumLength)
        #expect(request.content.utf16.count == CreateInquiryRequest.contentMaximumLength)
        #expect(request.subject?.count == CreateInquiryRequest.subjectMaximumLength / 2)
        #expect(request.content.count == CreateInquiryRequest.contentMaximumLength / 2)
    }

    @Test
    func theGuestScreenKeepsTheEmailReplyCopyAndHidesTheHistoryTab() {
        let model = SupportViewModel(
            isSignedIn: false,
            initialTab: .history,
            repository: SupportRepositorySpy()
        )

        #expect(!model.showsTabs)
        // A guest has no history to open, so a routed tab request cannot strand the form.
        #expect(model.selectedTab == .form)
        #expect(model.formDescriptionKey == "support.form.description")
        #expect(model.successMessageKey == "support.success.message")
        #expect(model.showsSignInHint)
    }

    @Test
    func aSignedInMemberGetsTheHistoryTabAndTheInAppReplyCopy() {
        let model = SupportViewModel(isSignedIn: true, repository: SupportRepositorySpy())

        #expect(model.showsTabs)
        #expect(model.selectedTab == .form)
        #expect(model.formDescriptionKey == "support.form.description.member")
        #expect(model.successMessageKey == "support.success.message.member")
        #expect(!model.showsSignInHint)

        let routed = SupportViewModel(
            isSignedIn: true,
            initialTab: .history,
            repository: SupportRepositorySpy()
        )
        #expect(routed.selectedTab == .history)
    }

    @Test
    func theHistoryRequestsTenPerPageAndAccumulatesEveryLoadedPage() async {
        let repository = SupportRepositorySpy(
            pages: [
                SupportFeatureTests.inquiryPage(number: 0, totalPages: 2, subjects: (0..<10).map { "Inquiry \($0)" }),
                SupportFeatureTests.inquiryPage(number: 1, totalPages: 2, subjects: ["Inquiry 10", "Inquiry 11"])
            ]
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)

        await model.loadInquiriesIfNeeded()

        #expect(repository.inquiryRequests == [SupportInquiryRequest(page: 0, size: 10)])
        #expect(model.inquiries.count == 10)
        #expect(model.hasMoreInquiries)

        await model.loadMoreInquiries()

        #expect(repository.inquiryRequests == [
            SupportInquiryRequest(page: 0, size: 10),
            SupportInquiryRequest(page: 1, size: 10)
        ])
        #expect(model.inquiries.compactMap(\.subject) == (0..<12).map { "Inquiry \($0)" })
        #expect(!model.hasMoreInquiries)
        #expect(!model.isLoadingInquiries)

        // A second visit to the tab reuses the pages that are already on screen.
        await model.loadInquiriesIfNeeded()
        #expect(repository.inquiryRequests.count == 2)
    }

    @Test
    func aFailedHistoryLoadCanBeRetried() async {
        let repository = SupportRepositorySpy(
            pages: [SupportFeatureTests.inquiryPage(number: 0, totalPages: 1, subjects: ["Only inquiry"])],
            failure: .transport
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)

        await model.loadInquiriesIfNeeded()

        #expect(model.inquiryLoadFailed)
        #expect(model.inquiries.isEmpty)
        #expect(!model.isLoadingInquiries)

        repository.stopFailing()
        await model.loadInquiries()

        #expect(!model.inquiryLoadFailed)
        #expect(model.inquiries.compactMap(\.subject) == ["Only inquiry"])
    }

    @Test
    func aNewSubmissionInvalidatesTheLoadedHistory() async {
        let repository = SupportRepositorySpy(
            pages: [SupportFeatureTests.inquiryPage(number: 0, totalPages: 1, subjects: ["Only inquiry"])]
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)
        await model.loadInquiriesIfNeeded()
        #expect(repository.inquiryRequests.count == 1)

        model.content = "One more question."
        await model.submit()
        await model.loadInquiriesIfNeeded()

        #expect(repository.inquiryRequests.count == 2)
    }

    @Test
    func theHistoryIsNeverRequestedForAGuest() async {
        let repository = SupportRepositorySpy(
            pages: [SupportFeatureTests.inquiryPage(number: 0, totalPages: 1, subjects: ["Only inquiry"])]
        )
        let model = SupportViewModel(isSignedIn: false, repository: repository)

        await model.loadInquiriesIfNeeded()
        await model.loadInquiries()

        #expect(repository.inquiryRequests.isEmpty)
        #expect(model.inquiries.isEmpty)
    }

    @Test
    func theServerContractIsDecodedWithoutTheAdminOnlyFields() throws {
        let page = try JSONDecoder().decode(
            PageResponse<MyInquiryDTO>.self,
            from: Data("""
                {
                  "content": [
                    {
                      "id": "6d2a4c86-1d8b-4c6f-9c1f-6a3a5b2f9c11",
                      "email": "member@dutypark.dev",
                      "subject": "Reporting a user",
                      "content": "The other member keeps posting spam.",
                      "status": "CLOSED",
                      "createdAt": "2026-08-12T09:51:51.163702",
                      "answer": "We removed the content.",
                      "answeredAt": "2026-08-13T10:00:00"
                    },
                    {
                      "id": "0b1f6a2c-5d5e-4a9e-9c11-9a2f7d3e1b40",
                      "email": null,
                      "subject": null,
                      "content": "Any update?",
                      "status": "OPEN",
                      "createdAt": "2026-08-14T09:00:00",
                      "answer": null,
                      "answeredAt": null
                    }
                  ],
                  "totalPages": 1,
                  "totalElements": 2,
                  "last": true,
                  "first": true,
                  "size": 10,
                  "number": 0,
                  "numberOfElements": 2,
                  "empty": false
                }
                """.utf8)
        )

        let answered = try #require(page.content.first)
        #expect(answered.status == .closed)
        #expect(answered.hasAnswer)
        #expect(answered.answerText == "We removed the content.")
        #expect(answered.answeredAt?.rawValue == "2026-08-13T10:00:00")

        let awaiting = try #require(page.content.last)
        // A member answered in the app may have sent no reply address at all.
        #expect(awaiting.email == nil)
        #expect(awaiting.status == .open)
        #expect(!awaiting.hasAnswer)
        #expect(awaiting.answerText == nil)
    }

    @Test
    func theHistoryRowLabelsFollowTheStatusAndTheAnswer() {
        let answered = SupportFeatureTests.inquiry(subject: "Reporting a user", status: .closed, answer: "We removed the content.")
        let awaiting = SupportFeatureTests.inquiry(subject: "   ", status: .open, answer: "   ")

        #expect(MyInquiryPresentation.statusKey(answered.status) == "support.history.status.closed")
        #expect(MyInquiryPresentation.statusKey(awaiting.status) == "support.history.status.open")
        #expect(MyInquiryPresentation.answerStateKey(answered) == "support.history.answered")
        #expect(MyInquiryPresentation.answerStateKey(awaiting) == "support.history.awaiting")
        // A blank answer is the same as no answer: the row must not promise a reply.
        #expect(!awaiting.hasAnswer)

        #expect(
            MyInquiryPresentation.subjectText(answered, locale: Locale(identifier: "ko")) == "Reporting a user"
        )
        #expect(
            MyInquiryPresentation.subjectText(awaiting, locale: Locale(identifier: "ko")) == "제목 없음"
        )
        #expect(
            MyInquiryPresentation.subjectText(awaiting, locale: Locale(identifier: "en")) == "No subject"
        )
    }

    @Test
    func historyDatesUseTheSelectedLocale() {
        let value = LocalDateTimeValue(rawValue: "2026-08-12T09:51:51.163702")

        #expect(MyInquiryPresentation.date(value, locale: Locale(identifier: "ko")) == "2026.08.12")
        #expect(MyInquiryPresentation.date(value, locale: Locale(identifier: "en")) == "Aug 12, 2026")
    }

    @Test
    func theReportHistoryRequestsTenPerPageAndAccumulatesEveryLoadedPage() async {
        let repository = SupportRepositorySpy(
            reportPages: [
                SupportFeatureTests.reportPage(number: 0, totalPages: 2, names: (0..<10).map { "Member \($0)" }),
                SupportFeatureTests.reportPage(number: 1, totalPages: 2, names: ["Member 10", "Member 11"])
            ]
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)

        await model.loadReportsIfNeeded()

        #expect(repository.reportRequests == [SupportInquiryRequest(page: 0, size: 10)])
        #expect(model.reports.count == 10)
        #expect(model.hasMoreReports)

        await model.loadMoreReports()

        #expect(model.reports.map(\.reportedMemberName) == (0..<12).map { "Member \($0)" })
        #expect(!model.hasMoreReports)

        // A second visit to the tab reuses the pages that are already on screen.
        await model.loadReportsIfNeeded()
        #expect(repository.reportRequests.count == 2)
    }

    @Test
    func aFailedReportHistoryLoadCanBeRetried() async {
        let repository = SupportRepositorySpy(
            reportPages: [SupportFeatureTests.reportPage(number: 0, totalPages: 1, names: ["Only member"])],
            failure: .transport
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)

        await model.loadReportsIfNeeded()

        #expect(model.reportLoadFailed)
        #expect(model.reports.isEmpty)

        repository.stopFailing()
        await model.loadReports()

        #expect(!model.reportLoadFailed)
        #expect(model.reports.map(\.reportedMemberName) == ["Only member"])
    }

    @Test
    func theReportHistoryIsNeverRequestedForAGuest() async {
        let repository = SupportRepositorySpy(
            reportPages: [SupportFeatureTests.reportPage(number: 0, totalPages: 1, names: ["Only member"])]
        )
        let model = SupportViewModel(isSignedIn: false, repository: repository)

        #expect(!model.showsTabs)
        await model.loadReportsIfNeeded()
        await model.loadReports()

        #expect(repository.reportRequests.isEmpty)
        #expect(model.reports.isEmpty)
    }

    /// The reporter sees the outcome, never how it was reached: the memo, the moderator and
    /// the stored evidence are administrator-only, and the target identifier is not sent.
    @Test
    func theReportContractIsDecodedWithoutTheAdminOnlyFields() throws {
        let page = try JSONDecoder().decode(
            PageResponse<MyReportDTO>.self,
            from: Data("""
                {
                  "content": [
                    {
                      "id": "5f6b0a52-6d4f-4a02-9e6a-3a6b1d2c4e88",
                      "targetType": "SCHEDULE",
                      "reportedMemberName": "Spammer",
                      "reason": "SPAM",
                      "detail": "Posts the same advertisement every day.",
                      "status": "RESOLVED",
                      "createdAt": "2026-08-12T09:51:51.163702",
                      "resolvedAt": "2026-08-13T10:00:00"
                    },
                    {
                      "id": "1a2b3c4d-5e6f-4a1b-8c2d-3e4f5a6b7c8d",
                      "targetType": "MEMBER",
                      "reportedMemberName": "Impostor",
                      "reason": "IMPERSONATION",
                      "detail": null,
                      "status": "OPEN",
                      "createdAt": "2026-08-14T09:00:00",
                      "resolvedAt": null
                    }
                  ],
                  "totalPages": 1,
                  "totalElements": 2,
                  "last": true,
                  "first": true,
                  "size": 10,
                  "number": 0,
                  "numberOfElements": 2,
                  "empty": false
                }
                """.utf8)
        )

        let resolved = try #require(page.content.first)
        #expect(resolved.targetType == .schedule)
        #expect(resolved.reason == .spam)
        #expect(resolved.status == .resolved)
        #expect(resolved.resolvedAt?.rawValue == "2026-08-13T10:00:00")

        let open = try #require(page.content.last)
        #expect(open.status == .open)
        #expect(open.detail == nil)
        #expect(open.resolvedAt == nil)
    }

    @Test
    func theReportRowLabelsFollowTheHandlingState() {
        #expect(MyReportPresentation.statusKey(.open) == "support.reports.status.open")
        #expect(MyReportPresentation.statusKey(.resolved) == "support.reports.status.resolved")
        #expect(MyReportPresentation.statusKey(.dismissed) == "support.reports.status.dismissed")
        #expect(MyReportPresentation.statusKey(.canceled) == "support.reports.status.canceled")

        #expect(MyReportPresentation.statusDescriptionKey(.open) == "support.reports.statusDescription.open")
        #expect(MyReportPresentation.statusDescriptionKey(.resolved) == "support.reports.statusDescription.resolved")
        #expect(MyReportPresentation.statusDescriptionKey(.dismissed) == "support.reports.statusDescription.dismissed")
        #expect(MyReportPresentation.statusDescriptionKey(.canceled) == "support.reports.statusDescription.canceled")

        #expect(MyReportPresentation.targetTypeKey(.member) == "support.reports.targetType.member")
        #expect(MyReportPresentation.targetTypeKey(.schedule) == "support.reports.targetType.schedule")
        #expect(MyReportPresentation.targetTypeKey(.todo) == "support.reports.targetType.todo")

        // The reason keeps the wording the reporter already read in the report sheet.
        #expect(MyReportPresentation.reasonText(.spam) == ReportLocalization.text("report.reason.spam"))
    }

    /// A withdrawal only takes back a review that has not happened yet, so every other
    /// state — including a report already withdrawn — offers nothing to press.
    @Test
    func onlyAReportStillWaitingForReviewOffersTheWithdrawal() {
        #expect(MyReportPresentation.canCancel(SupportFeatureTests.report(name: "Spammer", status: .open)))
        for handled: ReportStatus in [.resolved, .dismissed, .canceled] {
            #expect(
                !MyReportPresentation.canCancel(
                    SupportFeatureTests.report(name: "Spammer", status: handled)
                ),
                "Offered a withdrawal for \(handled)"
            )
        }
    }

    @Test
    func aWithdrawnReportIsDecodedFromTheServersOwnStatus() throws {
        let report = try JSONDecoder().decode(
            MyReportDTO.self,
            from: Data("""
                {
                  "id": "5f6b0a52-6d4f-4a02-9e6a-3a6b1d2c4e88",
                  "targetType": "MEMBER",
                  "reportedMemberName": "Spammer",
                  "reason": "SPAM",
                  "detail": null,
                  "status": "CANCELED",
                  "createdAt": "2026-08-12T09:51:51.163702",
                  "resolvedAt": "2026-08-13T10:00:00"
                }
                """.utf8)
        )

        #expect(report.status == .canceled)
        #expect(report.resolvedAt?.rawValue == "2026-08-13T10:00:00")
    }

    /// Withdrawing keeps the reporter's place in the list: only the answered row changes,
    /// and the pages already on screen are neither dropped nor fetched again.
    @Test
    func withdrawingAnOpenReportReplacesOnlyThatRow() async {
        let repository = SupportRepositorySpy(
            reportPages: [
                SupportFeatureTests.reportPage(
                    number: 0,
                    totalPages: 2,
                    reports: [
                        SupportFeatureTests.report(id: Self.withdrawnID, name: "Spammer"),
                        SupportFeatureTests.report(id: Self.untouchedID, name: "Impostor")
                    ]
                )
            ],
            cancelResult: SupportFeatureTests.report(
                id: Self.withdrawnID,
                name: "Spammer",
                status: .canceled
            )
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)
        await model.loadReportsIfNeeded()

        await model.cancelReport(id: Self.withdrawnID)

        #expect(repository.cancelRequests == [Self.withdrawnID])
        #expect(model.reports.map(\.id) == [Self.withdrawnID, Self.untouchedID])
        #expect(model.reports.map(\.status) == [.canceled, .open])
        #expect(model.reports.first?.resolvedAt?.rawValue == "2026-08-13T10:00:00")
        #expect(model.hasMoreReports)
        #expect(repository.reportRequests.count == 1)
        #expect(!model.isCancelingReport(Self.withdrawnID))
        #expect(model.reportCancelErrorKey == nil)
    }

    @Test
    func aReportThatIsNoLongerOpenSaysSoInsteadOfFailingGenerically() async {
        let repository = SupportRepositorySpy(
            reportPages: [
                SupportFeatureTests.reportPage(
                    number: 0,
                    totalPages: 1,
                    reports: [SupportFeatureTests.report(id: Self.withdrawnID, name: "Spammer")]
                )
            ],
            cancelFailure: .server(status: 400, code: "report.cancel.notOpen")
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)
        await model.loadReportsIfNeeded()

        await model.cancelReport(id: Self.withdrawnID)

        #expect(model.reportCancelErrorKey == "support.reports.cancel.error.notOpen")
        #expect(model.reports.map(\.status) == [.open])
        #expect(!model.isCancelingReport(Self.withdrawnID))
    }

    @Test
    func anyOtherWithdrawalFailureKeepsTheRowAndShowsTheGenericMessage() async {
        let repository = SupportRepositorySpy(
            reportPages: [
                SupportFeatureTests.reportPage(
                    number: 0,
                    totalPages: 1,
                    reports: [SupportFeatureTests.report(id: Self.withdrawnID, name: "Spammer")]
                )
            ],
            cancelFailure: .transport
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)
        await model.loadReportsIfNeeded()

        await model.cancelReport(id: Self.withdrawnID)

        #expect(model.reportCancelErrorKey == "support.reports.cancel.error")
        #expect(model.reports.map(\.status) == [.open])
    }

    /// The row offers no control for a handled report, so a stale request must not reach
    /// the server either.
    @Test
    func aHandledReportIsNeverSentToTheWithdrawalEndpoint() async {
        let repository = SupportRepositorySpy(
            reportPages: [
                SupportFeatureTests.reportPage(
                    number: 0,
                    totalPages: 1,
                    reports: [
                        SupportFeatureTests.report(
                            id: Self.withdrawnID,
                            name: "Spammer",
                            status: .resolved
                        )
                    ]
                )
            ]
        )
        let model = SupportViewModel(isSignedIn: true, repository: repository)
        await model.loadReportsIfNeeded()

        await model.cancelReport(id: Self.withdrawnID)
        await model.cancelReport(id: Self.untouchedID)

        #expect(repository.cancelRequests.isEmpty)
        #expect(model.reportCancelErrorKey == nil)
    }

    @Test
    func theWithdrawalPostsToTheDocumentedEndpointAndReturnsTheUpdatedRow() async throws {
        let recorder = SupportRequestRecorder()
        defer { SupportCancelURLProtocolStub.handler = nil }
        SupportCancelURLProtocolStub.handler = { request in
            recorder.append(request)
            return SupportFeatureTests.httpResponse(
                request,
                status: 200,
                body: """
                    {
                      "id": "\(Self.withdrawnID.uuidString.lowercased())",
                      "targetType": "MEMBER",
                      "reportedMemberName": "Spammer",
                      "reason": "SPAM",
                      "detail": null,
                      "status": "CANCELED",
                      "createdAt": "2026-08-12T09:51:51.163702",
                      "resolvedAt": "2026-08-13T10:00:00"
                    }
                    """
            )
        }

        let repository = LiveSupportRepository(client: Self.cancelClient())
        let updated = try await repository.cancelReport(id: Self.withdrawnID)

        #expect(recorder.paths == ["/api/reports/\(Self.withdrawnID.uuidString)/cancel"])
        #expect(recorder.methods == ["POST"])
        #expect(updated.id == Self.withdrawnID)
        #expect(updated.status == .canceled)
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
                "support.guest.entry",
                "support.guest.signInHint",
                "support.tab.form",
                "support.tab.history",
                "support.tab.reports",
                "support.history.emptyAction",
                "support.reports.empty",
                "support.reports.empty.description",
                "support.reports.loadMore",
                "support.reports.reportedAt",
                "support.reports.handledAt",
                "support.reports.target",
                "support.reports.reason",
                "support.reports.detail",
                "support.reports.privacyNotice",
                "support.reports.status.open",
                "support.reports.status.resolved",
                "support.reports.status.dismissed",
                "support.reports.status.canceled",
                "support.reports.statusDescription.open",
                "support.reports.statusDescription.resolved",
                "support.reports.statusDescription.dismissed",
                "support.reports.statusDescription.canceled",
                "support.reports.cancel",
                "support.reports.cancel.confirmTitle",
                "support.reports.cancel.confirmMessage",
                "support.reports.cancel.confirmAction",
                "support.reports.cancel.keep",
                "support.reports.cancel.errorTitle",
                "support.reports.cancel.error",
                "support.reports.cancel.error.notOpen",
                "support.reports.cancel.ok",
                "support.history.empty",
                "support.history.loadMore",
                "support.history.pendingAnswer",
                "support.form.description.member",
                "support.success.message.member"
            ] {
                #expect(
                    bundle.localizedString(forKey: key, value: key, table: "Support") != key,
                    "Missing \(key) for \(locale)"
                )
            }
        }
    }
}

nonisolated struct SupportInquiryRequest: Equatable, Sendable {
    let page: Int
    let size: Int
}

private final class SupportRepositorySpy: SupportRepository, @unchecked Sendable {
    private let lock = NSLock()
    private let failure: APIError?
    private let pages: [PageResponse<MyInquiryDTO>]
    private let reportPages: [PageResponse<MyReportDTO>]
    private let cancelResult: MyReportDTO?
    private let cancelFailure: APIError?
    private var storedSubmissions: [CreateInquiryRequest] = []
    private var storedAuthenticatedSubmissions: [Bool] = []
    private var storedInquiryRequests: [SupportInquiryRequest] = []
    private var storedReportRequests: [SupportInquiryRequest] = []
    private var storedCancelRequests: [UUID] = []
    private var isFailing: Bool

    init(
        pages: [PageResponse<MyInquiryDTO>] = [],
        reportPages: [PageResponse<MyReportDTO>] = [],
        cancelResult: MyReportDTO? = nil,
        cancelFailure: APIError? = nil,
        failure: APIError? = nil
    ) {
        self.pages = pages
        self.reportPages = reportPages
        self.cancelResult = cancelResult
        self.cancelFailure = cancelFailure
        self.failure = failure
        self.isFailing = failure != nil
    }

    var submissions: [CreateInquiryRequest] {
        lock.withLock { storedSubmissions }
    }

    var inquiryRequests: [SupportInquiryRequest] {
        lock.withLock { storedInquiryRequests }
    }

    var reportRequests: [SupportInquiryRequest] {
        lock.withLock { storedReportRequests }
    }

    var cancelRequests: [UUID] {
        lock.withLock { storedCancelRequests }
    }

    var authenticatedSubmissions: [Bool] {
        lock.withLock { storedAuthenticatedSubmissions }
    }

    func stopFailing() {
        lock.withLock { isFailing = false }
    }

    func submitInquiry(_ request: CreateInquiryRequest, authenticated: Bool) async throws {
        lock.withLock {
            storedSubmissions.append(request)
            storedAuthenticatedSubmissions.append(authenticated)
        }
        if let failure, lock.withLock({ isFailing }) { throw failure }
    }

    func fetchMyInquiries(page: Int, size: Int) async throws -> PageResponse<MyInquiryDTO> {
        lock.withLock { storedInquiryRequests.append(SupportInquiryRequest(page: page, size: size)) }
        if let failure, lock.withLock({ isFailing }) { throw failure }
        guard let response = pages.first(where: { $0.number == page }) else {
            throw APIError.invalidResponse
        }
        return response
    }

    func fetchMyReports(page: Int, size: Int) async throws -> PageResponse<MyReportDTO> {
        lock.withLock { storedReportRequests.append(SupportInquiryRequest(page: page, size: size)) }
        if let failure, lock.withLock({ isFailing }) { throw failure }
        guard let response = reportPages.first(where: { $0.number == page }) else {
            throw APIError.invalidResponse
        }
        return response
    }

    func cancelReport(id: UUID) async throws -> MyReportDTO {
        lock.withLock { storedCancelRequests.append(id) }
        if let cancelFailure { throw cancelFailure }
        if let failure, lock.withLock({ isFailing }) { throw failure }
        guard let cancelResult else { throw APIError.invalidResponse }
        return cancelResult
    }
}

extension SupportFeatureTests {
    /// Fixed identifiers so a withdrawal test can name the row it expects to change and
    /// the row it expects to be left alone.
    nonisolated static let withdrawnID = UUID(uuidString: "5f6b0a52-6d4f-4a02-9e6a-3a6b1d2c4e88")!
    nonisolated static let untouchedID = UUID(uuidString: "1a2b3c4d-5e6f-4a1b-8c2d-3e4f5a6b7c8d")!

    nonisolated static func supportClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SupportURLProtocolStub.self]
        return APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
    }

    /// The withdrawal contract gets its own protocol stub so it cannot race the inquiry
    /// contract test for the one shared handler.
    nonisolated static func cancelClient() -> APIClient {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SupportCancelURLProtocolStub.self]
        return APIClient(
            baseURL: URL(string: "https://dutypark.test/api/")!,
            session: URLSession(configuration: configuration)
        )
    }

    nonisolated static func httpResponse(
        _ request: URLRequest,
        status: Int,
        body: String = ""
    ) -> (HTTPURLResponse, Data) {
        (
            HTTPURLResponse(
                url: request.url!,
                statusCode: status,
                httpVersion: nil,
                headerFields: nil
            )!,
            Data(body.utf8)
        )
    }

    static func inquiry(
        id: UUID = UUID(),
        subject: String?,
        status: InquiryStatus = .open,
        answer: String? = nil
    ) -> MyInquiryDTO {
        MyInquiryDTO(
            id: id,
            email: "member@dutypark.dev",
            subject: subject,
            content: "The other member keeps posting spam.",
            status: status,
            createdAt: LocalDateTimeValue(rawValue: "2026-08-12T09:51:51.163702"),
            answer: answer,
            answeredAt: answer == nil ? nil : LocalDateTimeValue(rawValue: "2026-08-13T10:00:00")
        )
    }

    static func report(
        id: UUID = UUID(),
        name: String,
        status: ReportStatus = .open
    ) -> MyReportDTO {
        MyReportDTO(
            id: id,
            targetType: .member,
            reportedMemberName: name,
            reason: .spam,
            detail: "Posts the same advertisement every day.",
            status: status,
            createdAt: LocalDateTimeValue(rawValue: "2026-08-12T09:51:51.163702"),
            resolvedAt: status == .open ? nil : LocalDateTimeValue(rawValue: "2026-08-13T10:00:00")
        )
    }

    static func reportPage(
        number: Int,
        totalPages: Int,
        names: [String]
    ) -> PageResponse<MyReportDTO> {
        reportPage(number: number, totalPages: totalPages, reports: names.map { report(name: $0) })
    }

    static func reportPage(
        number: Int,
        totalPages: Int,
        reports: [MyReportDTO]
    ) -> PageResponse<MyReportDTO> {
        PageResponse(
            content: reports,
            totalPages: totalPages,
            totalElements: Int64(reports.count),
            last: number == totalPages - 1,
            first: number == 0,
            size: 10,
            number: number,
            numberOfElements: reports.count,
            empty: reports.isEmpty
        )
    }

    static func inquiryPage(
        number: Int,
        totalPages: Int,
        subjects: [String]
    ) -> PageResponse<MyInquiryDTO> {
        PageResponse(
            content: subjects.map { inquiry(subject: $0) },
            totalPages: totalPages,
            totalElements: Int64(subjects.count),
            last: number == totalPages - 1,
            first: number == 0,
            size: 10,
            number: number,
            numberOfElements: subjects.count,
            empty: subjects.isEmpty
        )
    }
}

private final class SupportRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var requests: [URLRequest] = []

    var paths: [String] {
        lock.withLock { requests.compactMap(\.url?.path) }
    }

    var methods: [String] {
        lock.withLock { requests.compactMap(\.httpMethod) }
    }

    func append(_ request: URLRequest) {
        lock.withLock { requests.append(request) }
    }

    func count(of path: String) -> Int {
        lock.withLock { requests.count(where: { $0.url?.path == path }) }
    }

    func removeAll() {
        lock.withLock { requests.removeAll() }
    }
}

private final class SupportURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("Missing SupportURLProtocolStub handler")
        }
        let result = handler(request)
        client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.1)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

private final class SupportCancelURLProtocolStub: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler: (@Sendable (URLRequest) -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        guard let handler = Self.handler else {
            fatalError("Missing SupportCancelURLProtocolStub handler")
        }
        let result = handler(request)
        client?.urlProtocol(self, didReceive: result.0, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: result.1)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}
