import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AccountDeletionFlowTests {
    private func makeReceiptStore() -> AccountDeletionReceiptStore {
        AccountDeletionReceiptStore(
            defaults: UserDefaults(suiteName: "AccountDeletionFlowTests.\(UUID().uuidString)")!,
            tokenStore: InMemoryReceiptTokenStore()
        )
    }

    @Test
    func accountDeletionRetentionNoticeAndEtaAreLocalizedAndScoped() {
        let expectedRetentionNoticeByLocale: [(Locale, String)] = [
            (
                .korean,
                "문의·신고 원문과 처리 기록, 그 기록에 포함된 이름 및 콘텐츠 snapshot은 계정 연결 해제 후에도 운영·분쟁 대응 또는 법령상 필요한 범위에서 제한적으로 보관될 수 있습니다. 해당 목적이 달성되면 삭제하거나 익명화합니다."
            ),
            (
                .english,
                "Original inquiry/report content, handling records, and any names or content snapshots included in those records may be retained in a limited scope after the account is disconnected when needed for operations, dispute handling, or legal obligations. They are deleted or anonymized once those purposes are fulfilled."
            ),
        ]
        let expectedEtaByLocale: [(Locale, String)] = [
            (
                .korean,
                "삭제 대상으로 안내한 계정 데이터와 파일은 보통 5분 이내에 처리됩니다. 문의·신고 기록에는 별도의 보관·삭제 기준이 적용될 수 있습니다."
            ),
            (
                .english,
                "The account data and files identified for deletion are usually processed within 5 minutes; inquiry and report records may follow a separate retention and deletion schedule."
            ),
        ]

        for (locale, expected) in expectedRetentionNoticeByLocale {
            let notice = SettingsLocalization.string(
                "settings.accountDeletion.retentionNotice",
                locale: locale
            )
            #expect(notice == expected)
            #expect(notice.rangeOfCharacter(from: .decimalDigits) == nil)
        }
        for (locale, expected) in expectedEtaByLocale {
            let eta = SettingsLocalization.string(
                "settings.accountDeletion.accepted.eta",
                locale: locale
            )
            #expect(eta == expected)
        }
    }

    @Test
    func accountDeletionScreensDiscloseRetentionAndReusePrivacyPolicyPresentation() throws {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let deletionSource = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Settings/AccountDeletionView.swift"),
            encoding: .utf8
        )
        let statusSource = try String(
            contentsOf: root.appending(path: "Dutypark/Features/Auth/AccountDeletionAcceptedView.swift"),
            encoding: .utf8
        )

        #expect(deletionSource.contains("settings.accountDeletion.retentionNotice"))
        #expect(deletionSource.contains("settings.policy.privacy"))
        #expect(deletionSource.contains("DeepLinkedPolicyView(type: .privacy"))
        #expect(statusSource.contains("settings.accountDeletion.retentionNotice"))
        #expect(statusSource.contains("settings.policy.privacy"))
        #expect(statusSource.contains("GuestPolicyView(type: .privacy)"))
    }

    @Test
    func finalDestructiveActionCopyMatchesResponsiveWebInEveryLanguage() {
        for (locale, expected) in [
            (Locale.korean, "계정 영구 삭제"),
            (Locale.english, "Permanently delete account"),
        ] {
            #expect(
                SettingsLocalization.string("settings.accountDeletion.final.action", locale: locale)
                    == expected
            )
        }
    }

    @Test
    func passwordReauthenticationConfirmationAndDeletionSucceedInOrder() async throws {
        let service = AccountDeletionServiceStub()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: makeReceiptStore(),
            ownerMemberID: 42
        )

        await model.load()
        #expect(model.preview != nil)
        #expect(model.flow.step == .scope)

        model.advance(memberName: "Shane")
        #expect(model.flow.step == .team)
        model.advance(memberName: "Shane")
        #expect(model.flow.step == .reauthentication)

        model.password = "secret"
        await model.reauthenticateWithPassword()
        #expect(model.flow.reauthProof == "proof")
        #expect(model.password.isEmpty)

        model.advance(memberName: "Shane")
        #expect(model.flow.step == .nameConfirmation)
        model.flow.typedName = "Shane"
        model.advance(memberName: "Shane")
        #expect(model.flow.step == .finalConfirmation)

        let completion = await model.submit()

        #expect(completion == .accepted)
        #expect(model.flow.reauthProof == nil)
        #expect(!model.isWorking)
        let calls = await service.recordedCalls()
        #expect(calls.previewCount == 1)
        #expect(calls.passwords == ["secret"])
        #expect(calls.deletionRequests.count == 1)
        #expect(calls.deletionRequests.first?.proof == "proof")
        #expect(calls.deletionRequests.first?.transferMemberID == nil)
        #expect(calls.deletionRequests.first?.receiptToken.isEmpty == false)
    }

    @Test
    func failedReauthenticationClearsPasswordAndProofAndShowsSpecificError() async {
        let service = AccountDeletionServiceStub(
            reauthError: .server(status: 401, code: "account.delete.reauthenticationFailed")
        )
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: makeReceiptStore(),
            ownerMemberID: 42
        )
        model.flow.storeProof("stale", expiresIn: 300)
        model.password = "wrong-password"

        await model.reauthenticateWithPassword()

        #expect(model.password.isEmpty)
        #expect(model.flow.reauthProof == nil)
        #expect(model.errorKey == "settings.accountDeletion.error.reauthentication")
        #expect(!model.isWorking)
    }

    @Test
    func exactNameConfirmationIsRequiredBeforeFinalConfirmation() {
        let model = AccountDeletionViewModel(
            service: AccountDeletionServiceStub(),
            receiptStore: makeReceiptStore(),
            ownerMemberID: 42
        )
        model.flow.step = .nameConfirmation
        model.flow.typedName = "Shane "

        model.advance(memberName: "Shane")

        #expect(model.flow.step == .nameConfirmation)
        #expect(model.errorKey == "settings.accountDeletion.error.nameMismatch")

        model.flow.typedName = "Shane"
        model.advance(memberName: "Shane")

        #expect(model.flow.step == .finalConfirmation)
        #expect(model.errorKey == nil)
    }

    @Test
    func cancellationClearsSensitiveStateWithoutCallingDeletionAPI() async {
        let service = AccountDeletionServiceStub()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: makeReceiptStore(),
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.selectedTransferMemberID = 9
        model.flow.typedName = "Shane"
        model.flow.storeProof("proof", expiresIn: 300)
        model.password = "secret"

        model.cancel()

        #expect(model.flow.reauthProof == nil)
        #expect(model.password.isEmpty)
        #expect(model.errorKey == nil)
        #expect((await service.recordedCalls()).deletionRequests.isEmpty)
    }

    @Test
    func failedDeletionConsumesProofAndReturnsToReauthentication() async {
        let service = AccountDeletionServiceStub(
            deletionError: .server(status: 409, code: "account.delete.teamAdminTransferRequired")
        )
        let receiptStore = makeReceiptStore()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        let completion = await model.submit()

        #expect(completion == nil)
        #expect(model.flow.step == .reauthentication)
        #expect(model.flow.reauthProof == nil)
        #expect(model.errorKey == "settings.accountDeletion.error.transferRequired")
        #expect(!model.isWorking)
        #expect(receiptStore.load() == nil)
    }

    @Test
    func networkFailurePreservesTheSameReceiptForAControlledRetry() async {
        let service = AccountDeletionServiceStub(deletionError: .transport)
        let receiptStore = makeReceiptStore()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof-1", expiresIn: 300)

        #expect(await model.submit() == .accepted)
        let firstToken = receiptStore.load()?.receiptToken
        #expect(firstToken?.isEmpty == false)

        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof-2", expiresIn: 300)
        #expect(await model.submit() == .accepted)
        let secondToken = receiptStore.load()?.receiptToken

        #expect(secondToken == firstToken)
        let calls = await service.recordedCalls()
        #expect(calls.deletionRequests.map(\.receiptToken) == [firstToken, firstToken].compactMap { $0 })
    }

    @Test
    func uncertainDeletionOutcomesContinueToStatusWithoutClearingReceipt() async {
        for deletionError in [
            APIError.transport,
            APIError.decoding,
            APIError.server(status: 503, code: "server_error"),
        ] {
            let service = AccountDeletionServiceStub(deletionError: deletionError)
            let receiptStore = makeReceiptStore()
            let model = AccountDeletionViewModel(
                service: service,
                receiptStore: receiptStore,
                ownerMemberID: 42
            )
            model.flow.step = .finalConfirmation
            model.flow.storeProof("proof", expiresIn: 300)

            #expect(await model.submit() == .accepted)
            #expect(receiptStore.load()?.ownerMemberID == 42)
            #expect(model.errorKey == nil)
        }
    }

    @Test
    func receiptStorageFailureBlocksDeletionRequestAndShowsActionableError() async {
        let service = AccountDeletionServiceStub()
        let suiteName = "AccountDeletionFlowTests.receiptStorageFailure.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: FailingReceiptTokenStore()
        )
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        #expect(await model.submit() == nil)
        #expect(model.errorKey == "settings.accountDeletion.error.receiptStorage")
        #expect((await service.recordedCalls()).deletionRequests.isEmpty)
    }

    @Test
    func deletionForAnotherAccountIsBlockedWithoutOverwritingItsReceipt() async throws {
        let service = AccountDeletionServiceStub()
        let suiteName = "AccountDeletionFlowTests.otherReceipt.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: InMemoryReceiptTokenStore()
        )
        let existingReceipt = AccountDeletionReceipt(
            jobId: 0,
            status: "PENDING",
            ownerMemberID: 7,
            receiptToken: String(repeating: "C", count: 43),
            estimatedCompletionAt: "2026-08-29T12:05:00Z"
        )
        try receiptStore.save(existingReceipt)
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        #expect(await model.submit() == .existingReceipt)
        #expect(model.errorKey == "settings.accountDeletion.error.receiptOtherAccount")
        #expect(receiptStore.load() == existingReceipt)
        #expect((await service.recordedCalls()).deletionRequests.isEmpty)
    }

    @Test
    func ambiguousAcceptedResponseKeepsTheProvisionalReceiptForStatusLookup() async {
        let service = AccountDeletionServiceStub(mismatchesReceiptToken: true)
        let receiptStore = makeReceiptStore()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        #expect(await model.submit() == .accepted)
        #expect(model.acceptedResponse == nil)
        #expect(receiptStore.load()?.receiptToken.isEmpty == false)
    }

    @Test
    func acceptedResponseMetadataFailureKeepsTheProvisionalReceiptForStatusLookup() async {
        let service = AccountDeletionServiceStub()
        let suiteName = "AccountDeletionFlowTests.receiptMetadataFailure.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: FailOnSecondReceiptTokenStore()
        )
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        #expect(await model.submit() == .accepted)
        #expect(model.acceptedResponse == nil)
        #expect(receiptStore.load()?.ownerMemberID == 42)
        #expect(receiptStore.load()?.status == "PENDING")
    }

    @Test
    func definitiveAlreadyPendingRejectionClearsReceiptAndRequiresFreshProof() async {
        let service = AccountDeletionServiceStub(
            deletionError: .server(status: 409, code: "account.delete.alreadyPending")
        )
        let receiptStore = makeReceiptStore()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: receiptStore,
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        let completion = await model.submit()

        #expect(completion == nil)
        #expect(model.flow.step == .reauthentication)
        #expect(model.flow.reauthProof == nil)
        #expect(model.errorKey == "settings.accountDeletion.error.alreadyPending")
        #expect(!model.isWorking)
        #expect(receiptStore.load() == nil)
    }

    @Test
    func duplicateSubmissionIsIgnoredWhileFirstDeletionIsInFlight() async throws {
        let service = AccountDeletionServiceStub(suspendsDeletion: true)
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: makeReceiptStore(),
            ownerMemberID: 42
        )
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        let first = Task { await model.submit() }
        try await waitUntil { await service.deletionStarted() }
        #expect(model.isWorking)

        let duplicate = await model.submit()

        #expect(duplicate == nil)
        #expect((await service.recordedCalls()).deletionRequests.count == 1)

        await service.resumeDeletion()
        #expect(await first.value == .accepted)
        #expect(!model.isWorking)
    }

    @Test
    func deletionCannotBeSubmittedBeforeFinalConfirmation() async {
        let service = AccountDeletionServiceStub()
        let model = AccountDeletionViewModel(
            service: service,
            receiptStore: makeReceiptStore(),
            ownerMemberID: 42
        )
        model.flow.step = .nameConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        let completion = await model.submit()

        #expect(completion == nil)
        #expect((await service.recordedCalls()).deletionRequests.isEmpty)
        #expect(model.flow.reauthProof == "proof")
    }

    private func waitUntil(
        _ condition: @escaping @Sendable () async -> Bool
    ) async throws {
        for _ in 0..<200 {
            if await condition() { return }
            try await Task.sleep(for: .milliseconds(1))
        }
        Issue.record("Condition was not satisfied before the timeout")
    }
}

private struct AccountDeletionServiceCalls: Sendable {
    struct DeletionRequest: Equatable, Sendable {
        let proof: String
        let transferMemberID: Int64?
        let receiptToken: String
    }

    let previewCount: Int
    let passwords: [String]
    let deletionRequests: [DeletionRequest]
}

private actor AccountDeletionServiceStub: AccountDeletionServicing {
    private let preview: AccountDeletionPreview
    private let reauthError: APIError?
    private let deletionError: APIError?
    private let suspendsDeletion: Bool
    private let mismatchesReceiptToken: Bool
    private var previewCount = 0
    private var passwords: [String] = []
    private var deletionRequests: [AccountDeletionServiceCalls.DeletionRequest] = []
    private var isDeletionStarted = false
    private var deletionReleaseRequested = false
    private var deletionContinuation: CheckedContinuation<Void, Never>?

    init(
        preview: AccountDeletionPreview = .init(
            hasPassword: true,
            socialProviders: [],
            teamImpact: nil,
            auxiliaryImpacts: []
        ),
        reauthError: APIError? = nil,
        deletionError: APIError? = nil,
        suspendsDeletion: Bool = false,
        mismatchesReceiptToken: Bool = false
    ) {
        self.preview = preview
        self.reauthError = reauthError
        self.deletionError = deletionError
        self.suspendsDeletion = suspendsDeletion
        self.mismatchesReceiptToken = mismatchesReceiptToken
    }

    func accountDeletionPreview() async throws -> AccountDeletionPreview {
        previewCount += 1
        return preview
    }

    func reauthenticateForAccountDeletion(password: String) async throws -> AccountDeletionReauthProof {
        passwords.append(password)
        if let reauthError { throw reauthError }
        return AccountDeletionReauthProof(reauthProof: "proof", expiresIn: 300)
    }

    func requestAccountDeletion(
        reauthProof: String,
        receiptToken: String,
        transferAdminToMemberId: Int64?
    ) async throws -> AccountDeletionAccepted {
        deletionRequests.append(.init(
            proof: reauthProof,
            transferMemberID: transferAdminToMemberId,
            receiptToken: receiptToken
        ))
        isDeletionStarted = true
        if suspendsDeletion, !deletionReleaseRequested {
            await withCheckedContinuation { continuation in
                deletionContinuation = continuation
            }
        }
        if let deletionError { throw deletionError }
        return AccountDeletionAccepted(
            jobId: 44,
            status: "ACCEPTED",
            receiptToken: mismatchesReceiptToken ? "server-token" : receiptToken,
            estimatedCompletionAt: "2026-08-29T12:05:00Z"
        )
    }

    func deletionStarted() -> Bool {
        isDeletionStarted
    }

    func resumeDeletion() {
        deletionReleaseRequested = true
        deletionContinuation?.resume()
        deletionContinuation = nil
    }

    func recordedCalls() -> AccountDeletionServiceCalls {
        AccountDeletionServiceCalls(
            previewCount: previewCount,
            passwords: passwords,
            deletionRequests: deletionRequests
        )
    }
}

@MainActor
private final class InMemoryReceiptTokenStore: AccountDeletionReceiptTokenStoring {
    private var token: String?

    func loadToken() throws -> String? { token }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func clearToken() {
        token = nil
    }
}

@MainActor
private final class FailingReceiptTokenStore: AccountDeletionReceiptTokenStoring {
    func loadToken() throws -> String? { nil }

    func saveToken(_ token: String) throws {
        throw AccountDeletionReceiptStoreError.secureStorageFailed
    }

    func clearToken() {}
}

@MainActor
private final class FailOnSecondReceiptTokenStore: AccountDeletionReceiptTokenStoring {
    private var token: String?
    private var saveCount = 0

    func loadToken() throws -> String? { token }

    func saveToken(_ token: String) throws {
        saveCount += 1
        guard saveCount == 1 else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
        self.token = token
    }

    func clearToken() {
        token = nil
    }
}
