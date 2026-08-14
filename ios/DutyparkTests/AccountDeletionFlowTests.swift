import Foundation
import Testing
@testable import Dutypark

@Suite(.serialized)
@MainActor
struct AccountDeletionFlowTests {
    @Test
    func passwordReauthenticationConfirmationAndDeletionSucceedInOrder() async throws {
        let service = AccountDeletionServiceStub()
        let model = AccountDeletionViewModel(service: service)

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
        #expect(calls.deletionRequests == [.init(proof: "proof", transferMemberID: nil)])
    }

    @Test
    func failedReauthenticationClearsPasswordAndProofAndShowsSpecificError() async {
        let service = AccountDeletionServiceStub(
            reauthError: .server(status: 401, code: "account.delete.reauthenticationFailed")
        )
        let model = AccountDeletionViewModel(service: service)
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
        let model = AccountDeletionViewModel(service: AccountDeletionServiceStub())
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
        let model = AccountDeletionViewModel(service: service)
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
        let model = AccountDeletionViewModel(service: service)
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        let completion = await model.submit()

        #expect(completion == nil)
        #expect(model.flow.step == .reauthentication)
        #expect(model.flow.reauthProof == nil)
        #expect(model.errorKey == "settings.accountDeletion.error.transferRequired")
        #expect(!model.isWorking)
    }

    @Test
    func alreadyPendingDeletionIsTreatedAsCompletedAndConsumesProof() async {
        let service = AccountDeletionServiceStub(
            deletionError: .server(status: 409, code: "account.delete.alreadyPending")
        )
        let model = AccountDeletionViewModel(service: service)
        model.flow.step = .finalConfirmation
        model.flow.storeProof("proof", expiresIn: 300)

        let completion = await model.submit()

        #expect(completion == .alreadyPending)
        #expect(model.flow.reauthProof == nil)
        #expect(model.errorKey == nil)
        #expect(!model.isWorking)
    }

    @Test
    func duplicateSubmissionIsIgnoredWhileFirstDeletionIsInFlight() async throws {
        let service = AccountDeletionServiceStub(suspendsDeletion: true)
        let model = AccountDeletionViewModel(service: service)
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
        let model = AccountDeletionViewModel(service: service)
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
        suspendsDeletion: Bool = false
    ) {
        self.preview = preview
        self.reauthError = reauthError
        self.deletionError = deletionError
        self.suspendsDeletion = suspendsDeletion
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
        transferAdminToMemberId: Int64?
    ) async throws -> AccountDeletionAccepted {
        deletionRequests.append(.init(
            proof: reauthProof,
            transferMemberID: transferAdminToMemberId
        ))
        isDeletionStarted = true
        if suspendsDeletion, !deletionReleaseRequested {
            await withCheckedContinuation { continuation in
                deletionContinuation = continuation
            }
        }
        if let deletionError { throw deletionError }
        return AccountDeletionAccepted(jobId: 44, status: "ACCEPTED")
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
