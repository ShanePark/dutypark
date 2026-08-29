import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AccountDeletionReceiptTests {
    @Test
    func receiptStoreRoundTripsAndClearsTheOpaqueReceipt() throws {
        let suiteName = "AccountDeletionReceiptTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: InMemoryReceiptTokenStore()
        )
        let prepared = try store.prepareReceiptToken(
            ownerMemberID: 42,
            now: Date(timeIntervalSince1970: 0)
        )
        #expect(prepared.count == 43)
        #expect(prepared.allSatisfy { $0.isNumber || $0.isLetter || $0 == "-" || $0 == "_" })

        let receipt = AccountDeletionReceipt(
            jobId: 42,
            status: "ACCEPTED",
            ownerMemberID: 42,
            receiptToken: prepared,
            estimatedCompletionAt: "2026-08-29T12:05:00Z"
        )

        try store.save(receipt)

        let restored = try #require(store.load())
        #expect(restored.jobId == 0)
        #expect(restored.status == receipt.status)
        #expect(restored.ownerMemberID == receipt.ownerMemberID)
        #expect(restored.receiptToken == receipt.receiptToken)
        #expect(restored.estimatedCompletionAt == receipt.estimatedCompletionAt)
        store.clear()
        #expect(store.load() == nil)
    }

    @Test
    func receiptStoreDoesNotReuseAnotherAccountsReceiptOrOverwriteIt() throws {
        let suiteName = "AccountDeletionReceiptTests.owner.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: InMemoryReceiptTokenStore()
        )
        let receipt = AccountDeletionReceipt(
            jobId: 42,
            status: "PENDING",
            ownerMemberID: 42,
            receiptToken: String(repeating: "A", count: 43),
            estimatedCompletionAt: "2026-08-29T12:05:00Z"
        )
        try store.save(receipt)

        #expect(throws: AccountDeletionReceiptStoreError.receiptBelongsToAnotherAccount) {
            try store.prepareReceiptToken(ownerMemberID: 99)
        }
        let restored = try #require(store.load())
        #expect(restored.jobId == 0)
        #expect(restored.status == receipt.status)
        #expect(restored.ownerMemberID == receipt.ownerMemberID)
        #expect(restored.receiptToken == receipt.receiptToken)
        #expect(restored.estimatedCompletionAt == receipt.estimatedCompletionAt)
    }

    @Test
    func acceptedResponseCarriesTheReceiptContract() throws {
        let data = Data(
            #"{"jobId":42,"status":"ACCEPTED","receiptToken":"receipt-token","estimatedCompletionAt":"2026-08-29T12:05:00Z"}"#.utf8
        )

        let response = try JSONDecoder().decode(AccountDeletionAccepted.self, from: data)

        #expect(response.receiptToken == "receipt-token")
        #expect(response.estimatedCompletionAt == "2026-08-29T12:05:00Z")
        #expect(response.receipt(ownerMemberID: 42) == AccountDeletionReceipt(
            jobId: 42,
            status: "ACCEPTED",
            ownerMemberID: 42,
            receiptToken: "receipt-token",
            estimatedCompletionAt: "2026-08-29T12:05:00Z"
        ))
    }

    @Test
    func processingPollTransitionsToCompletedAndEmitsSuccessOnlyOnce() async throws {
        let service = AccountDeletionStatusServiceStub(
            responses: [
                .init(status: "PROCESSING", estimatedCompletionAt: "2026-08-29T12:05:00Z"),
                .init(
                    status: "COMPLETED",
                    estimatedCompletionAt: "2026-08-29T12:05:00Z",
                    completedAt: "2026-08-29T12:04:00Z"
                ),
            ]
        )
        let model = AccountDeletionStatusViewModel(
            receipt: AccountDeletionReceipt(
                jobId: 42,
                status: "ACCEPTED",
                ownerMemberID: 42,
                receiptToken: "receipt-token",
                estimatedCompletionAt: "2026-08-29T12:05:00Z"
            ),
            service: service,
            pollInterval: .milliseconds(1)
        )

        await model.pollOnce()
        #expect(model.presentation == .processing)
        await model.pollOnce()
        #expect(model.presentation == .completed(completedAt: "2026-08-29T12:04:00Z"))
        #expect(model.terminalHaptic == .success)
        await model.pollOnce()
        #expect(model.terminalHaptic == .success)
        #expect(await service.requestedTokens() == ["receipt-token", "receipt-token"])
    }

    @Test
    func failedPollShowsSupportStateAndErrorHaptic() async {
        let service = AccountDeletionStatusServiceStub(
            responses: [.init(status: "FAILED", estimatedCompletionAt: "2026-08-29T12:05:00Z")]
        )
        let model = AccountDeletionStatusViewModel(
            receipt: .init(
                jobId: 42,
                status: "ACCEPTED",
                ownerMemberID: 42,
                receiptToken: "receipt-token",
                estimatedCompletionAt: "2026-08-29T12:05:00Z"
            ),
            service: service
        )

        await model.pollOnce()

        #expect(model.presentation == .failed)
        #expect(model.terminalHaptic == .error)
    }

    @Test
    func missingOrExpiredReceiptIsNeutralAndDoesNotPretendDeletionCompleted() async {
        let service = AccountDeletionStatusServiceStub(
            error: .server(status: 404, code: "account.delete.receiptNotFound")
        )
        let model = AccountDeletionStatusViewModel(
            receipt: .init(
                jobId: 42,
                status: "ACCEPTED",
                ownerMemberID: 42,
                receiptToken: "expired-token",
                estimatedCompletionAt: "2026-08-29T12:05:00Z"
            ),
            service: service,
            now: { Date(timeIntervalSince1970: 1788005100) }
        )

        await model.pollOnce()

        #expect(model.presentation == .expired)
        #expect(model.terminalHaptic == nil)
    }

    @Test
    func provisionalReceipt404BeforeEtaKeepsPollingInsteadOfExpiring() async {
        let eta = "2026-08-29T12:05:00Z"
        let beforeEta = Date(timeIntervalSince1970: 1788005040) // 2026-08-29 12:04:00 UTC
        let service = AccountDeletionStatusServiceStub(
            error: .server(status: 404, code: "account.delete.receiptNotFound")
        )
        let model = AccountDeletionStatusViewModel(
            receipt: .init(
                jobId: 0,
                status: "PENDING",
                ownerMemberID: 42,
                receiptToken: "provisional-token",
                estimatedCompletionAt: eta
            ),
            service: service,
            now: { beforeEta }
        )

        await model.pollOnce()

        #expect(model.presentation == .processing)
        #expect(model.terminalHaptic == nil)
        #expect(model.lastRequestFailed == false)
        #expect(await service.requestedTokens() == ["provisional-token"])
    }

    @Test
    func provisionalReceipt404AtOrAfterEtaBecomesNeutralExpiredState() async {
        let eta = "2026-08-29T12:05:00Z"
        let atEta = Date(timeIntervalSince1970: 1788005100) // 2026-08-29 12:05:00 UTC
        let service = AccountDeletionStatusServiceStub(
            error: .server(status: 404, code: "account.delete.receiptNotFound")
        )
        let model = AccountDeletionStatusViewModel(
            receipt: .init(
                jobId: 0,
                status: "PENDING",
                ownerMemberID: 42,
                receiptToken: "provisional-token",
                estimatedCompletionAt: eta
            ),
            service: service,
            now: { atEta }
        )

        await model.pollOnce()

        #expect(model.presentation == .expired)
        #expect(model.terminalHaptic == nil)
    }

    @Test
    func fractionalSecondEta404AtOrAfterEtaBecomesNeutralExpiredState() async {
        for eta in [
            "2026-08-29T12:05:00.123456Z",
            "2026-08-29T12:05:00.123456789Z",
        ] {
            let service = AccountDeletionStatusServiceStub(
                error: .server(status: 404, code: "account.delete.receiptNotFound")
            )
            let model = AccountDeletionStatusViewModel(
                receipt: .init(
                    jobId: 0,
                    status: "PENDING",
                    ownerMemberID: 42,
                    receiptToken: "provisional-token",
                    estimatedCompletionAt: eta
                ),
                service: service,
                now: { Date(timeIntervalSince1970: 1788005101) }
            )

            await model.pollOnce()

            #expect(model.presentation == .expired)
            #expect(model.terminalHaptic == nil)
        }
    }

    @Test
    func missingOrMalformedEta404BecomesUnavailableInsteadOfPollingForever() async {
        for eta in ["", "not-an-instant"] {
            let service = AccountDeletionStatusServiceStub(
                error: .server(status: 404, code: "account.delete.receiptNotFound")
            )
            let model = AccountDeletionStatusViewModel(
                receipt: .init(
                    jobId: 0,
                    status: "PENDING",
                    ownerMemberID: 0,
                    receiptToken: "provisional-token",
                    estimatedCompletionAt: eta
                ),
                service: service
            )

            await model.start()

            #expect(model.presentation == .unavailable)
            #expect(model.terminalHaptic == nil)
            #expect(model.isPolling == false)
            #expect(await service.requestedTokens().count == 1)
        }
    }

    @Test
    func tokenOnlyOrCorruptMetadata404BecomesUnavailableAndCanBeCleared() async throws {
        let metadataVariants: [Data?] = [nil, Data("not-json".utf8)]
        for metadata in metadataVariants {
            let suiteName = "AccountDeletionReceiptTests.unusableMetadata.\(UUID().uuidString)"
            let defaults = try #require(UserDefaults(suiteName: suiteName))
            defer { defaults.removePersistentDomain(forName: suiteName) }
            let tokenStore = InMemoryReceiptTokenStore()
            let receiptStore = AccountDeletionReceiptStore(
                defaults: defaults,
                tokenStore: tokenStore
            )
            _ = try receiptStore.prepareReceiptToken(
                ownerMemberID: 42,
                now: Date(timeIntervalSince1970: 0)
            )
            if let metadata {
                defaults.set(metadata, forKey: "dp-account-deletion-receipt")
            } else {
                defaults.removeObject(forKey: "dp-account-deletion-receipt")
            }

            let loaded = try #require(receiptStore.load())
            #expect(loaded.ownerMemberID == 0)
            #expect(loaded.estimatedCompletionAt.isEmpty)

            let service = AccountDeletionStatusServiceStub(
                error: .server(status: 404, code: "account.delete.receiptNotFound")
            )
            let model = AccountDeletionStatusViewModel(
                receipt: loaded,
                service: service
            )
            await model.pollOnce()

            #expect(model.presentation == .unavailable)
            #expect(model.terminalHaptic == nil)

            receiptStore.clear()
            #expect(receiptStore.load() == nil)
        }
    }

    @Test
    func transientKeychainFailurePreservesMetadataAndCannotOverwriteReceipt() throws {
        let suiteName = "AccountDeletionReceiptTests.keychainUnavailable.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let sourceTokenStore = InMemoryReceiptTokenStore()
        let sourceStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: sourceTokenStore
        )
        let token = try sourceStore.prepareReceiptToken(
            ownerMemberID: 42,
            now: Date(timeIntervalSince1970: 0)
        )
        let metadataBeforeFailure = try #require(
            defaults.data(forKey: "dp-account-deletion-receipt")
        )

        let tokenStore = TemporarilyUnavailableReceiptTokenStore(token: token)
        let protectedStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: tokenStore
        )

        #expect(protectedStore.load() == nil)
        #expect(defaults.data(forKey: "dp-account-deletion-receipt") == metadataBeforeFailure)
        #expect(throws: AccountDeletionReceiptStoreError.secureStorageFailed) {
            try protectedStore.save(AccountDeletionReceipt(
                jobId: 9,
                status: "ACCEPTED",
                ownerMemberID: 99,
                receiptToken: String(repeating: "D", count: 43),
                estimatedCompletionAt: "2026-08-29T12:05:00Z"
            ))
        }
        #expect(defaults.data(forKey: "dp-account-deletion-receipt") == metadataBeforeFailure)

        tokenStore.isAvailable = true
        let restored = try #require(protectedStore.load())
        #expect(restored.ownerMemberID == 42)
        #expect(restored.receiptToken == token)
    }

    @Test
    func receiptStoreRejectsReceiptTokensOutsideTheBase64URLContract() throws {
        let suiteName = "AccountDeletionReceiptTests.invalidToken.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: InMemoryReceiptTokenStore()
        )

        #expect(throws: AccountDeletionReceiptStoreError.secureStorageFailed) {
            try store.save(AccountDeletionReceipt(
                jobId: 1,
                status: "PENDING",
                ownerMemberID: 42,
                receiptToken: String(repeating: "A", count: 42),
                estimatedCompletionAt: "2026-08-29T12:05:00Z"
            ))
        }
        #expect(store.load() == nil)
    }

    @Test
    func sessionCleanupPersistsReceiptAcrossAStoreRecreationUntilExplicitDismissal() async {
        let suiteName = "AccountDeletionReceiptTests.session.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let tokenStore = InMemoryReceiptTokenStore()
        let receiptStore = AccountDeletionReceiptStore(
            defaults: defaults,
            tokenStore: tokenStore
        )
        let receipt = AccountDeletionReceipt(
            jobId: 42,
            status: "ACCEPTED",
            ownerMemberID: 42,
            receiptToken: String(repeating: "B", count: 43),
            estimatedCompletionAt: "2026-08-29T12:05:00Z"
        )

        let store = SessionStore(
            initialState: .authenticated(Self.member),
            localDataPurger: NoopSessionLocalDataPurger(),
            accountDeletionReceiptStore: receiptStore
        )
        await store.completeAccountDeletion(
            expectedMemberID: Self.member.id,
            expectedAuthenticationSessionGeneration: store
                .authenticationSessionGenerationForCurrentAccount!,
            receipt: receipt
        )

        #expect(store.state == .guest)
        #expect(store.accountDeletionReceipt == receipt)
        #expect(store.accountDeletionAcceptedPresentation == .accepted)

        let relaunchedStore = SessionStore(
            initialState: .restoring,
            localDataPurger: NoopSessionLocalDataPurger(),
            accountDeletionReceiptStore: receiptStore
        )
        #expect(relaunchedStore.accountDeletionReceipt?.jobId == 0)
        #expect(relaunchedStore.accountDeletionReceipt?.status == receipt.status)
        #expect(relaunchedStore.accountDeletionReceipt?.ownerMemberID == receipt.ownerMemberID)
        #expect(relaunchedStore.accountDeletionReceipt?.receiptToken == receipt.receiptToken)
        #expect(relaunchedStore.accountDeletionReceipt?.estimatedCompletionAt == receipt.estimatedCompletionAt)
        #expect(relaunchedStore.accountDeletionAcceptedPresentation == .accepted)

        relaunchedStore.dismissAccountDeletionAcceptedPresentation()
        #expect(relaunchedStore.accountDeletionReceipt == nil)
        #expect(receiptStore.load() == nil)
    }

    private static let member = LoginMember(
        id: 42,
        email: "member@dutypark.dev",
        name: "Member",
        teamId: nil,
        team: nil,
        isAdmin: false,
        isImpersonating: false,
        originalMemberId: nil
    )
}

private actor AccountDeletionStatusServiceStub: AccountDeletionStatusServicing {
    private let responses: [AccountDeletionStatusResponse]
    private let error: APIError?
    private var tokens: [String] = []

    init(
        responses: [AccountDeletionStatusResponse] = [],
        error: APIError? = nil
    ) {
        self.responses = responses
        self.error = error
    }

    func accountDeletionStatus(receiptToken: String) async throws -> AccountDeletionStatusResponse {
        tokens.append(receiptToken)
        if let error { throw error }
        let index = min(tokens.count - 1, responses.count - 1)
        return responses[index]
    }

    func requestedTokens() -> [String] { tokens }
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
private final class TemporarilyUnavailableReceiptTokenStore: AccountDeletionReceiptTokenStoring {
    private var token: String?
    var isAvailable = false

    init(token: String) {
        self.token = token
    }

    func loadToken() throws -> String? {
        guard isAvailable else {
            throw AccountDeletionReceiptStoreError.secureStorageFailed
        }
        return token
    }

    func saveToken(_ token: String) throws {
        self.token = token
    }

    func clearToken() {
        token = nil
    }
}
