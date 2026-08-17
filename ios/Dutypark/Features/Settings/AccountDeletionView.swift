import Combine
import SwiftUI

nonisolated enum AccountDeletionStep: Int, CaseIterable, Sendable {
    case scope
    case team
    case reauthentication
    case nameConfirmation
    case finalConfirmation
}

nonisolated struct AccountDeletionFlowState: Equatable, Sendable {
    var step: AccountDeletionStep = .scope
    var selectedTransferMemberID: Int64?
    var typedName = ""
    private(set) var reauthProof: String?
    private(set) var proofExpiresAt: Date?

    mutating func storeProof(_ proof: String, expiresIn: Int, now: Date = .now) {
        reauthProof = proof
        proofExpiresAt = now.addingTimeInterval(TimeInterval(expiresIn))
    }

    mutating func clearProof() {
        reauthProof = nil
        proofExpiresAt = nil
    }

    mutating func validProof(at now: Date = .now) -> String? {
        guard let proof = reauthProof,
              let expiration = proofExpiresAt,
              expiration > now
        else {
            clearProof()
            return nil
        }
        return proof
    }

    func canLeaveTeamStep(preview: AccountDeletionPreview) -> Bool {
        guard let team = preview.teamImpact,
              team.isAdmin,
              team.activeMemberCount > 1
        else { return true }
        return team.transferCandidates.contains { $0.memberId == selectedTransferMemberID }
    }

    func nameMatches(_ memberName: String) -> Bool {
        typedName == memberName
    }
}

nonisolated enum AccountDeletionCompletion: Equatable, Sendable {
    case accepted
    case alreadyPending
}

@MainActor
final class AccountDeletionViewModel: ObservableObject {
    @Published private(set) var preview: AccountDeletionPreview?
    @Published var flow = AccountDeletionFlowState()
    @Published var password = ""
    @Published private(set) var isLoading = false
    @Published private(set) var isWorking = false
    @Published private(set) var errorKey: String?

    private let service: any AccountDeletionServicing
    private let oauthClient: MobileOAuthClient
    private let appleSignInClient: AppleSignInClient

    init(
        service: (any AccountDeletionServicing)? = nil,
        oauthClient: MobileOAuthClient = MobileOAuthClient(),
        appleSignInClient: AppleSignInClient = AppleSignInClient()
    ) {
        self.service = service ?? Self.defaultService()
        self.oauthClient = oauthClient
        self.appleSignInClient = appleSignInClient
    }

    private static func defaultService() -> any AccountDeletionServicing {
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-account-deletion") {
            return AccountDeletionUITestingService()
        }
        #endif
        return SettingsService()
    }

    var requiresAdminTransfer: Bool {
        guard let team = preview?.teamImpact else { return false }
        return team.isAdmin && team.activeMemberCount > 1
    }

    var hasTransferCandidates: Bool {
        preview?.teamImpact?.transferCandidates.isEmpty == false
    }

    var canContinue: Bool {
        guard let preview else { return false }
        return switch flow.step {
        case .scope:
            true
        case .team:
            flow.canLeaveTeamStep(preview: preview)
        case .reauthentication:
            flow.reauthProof != nil
        case .nameConfirmation:
            false // The view checks the current member name.
        case .finalConfirmation:
            false
        }
    }

    func load() async {
        guard preview == nil, !isLoading else { return }
        isLoading = true
        errorKey = nil
        defer { isLoading = false }
        do {
            preview = try await service.accountDeletionPreview()
        } catch {
            errorKey = Self.errorKey(for: error)
        }
    }

    func advance(memberName: String) {
        errorKey = nil
        switch flow.step {
        case .scope:
            flow.step = .team
        case .team:
            guard let preview, flow.canLeaveTeamStep(preview: preview) else {
                errorKey = hasTransferCandidates
                    ? "settings.accountDeletion.error.transferRequired"
                    : "settings.accountDeletion.error.noTransferCandidate"
                return
            }
            flow.step = .reauthentication
        case .reauthentication:
            guard flow.validProof() != nil else {
                errorKey = "settings.accountDeletion.error.proofExpired"
                return
            }
            flow.step = .nameConfirmation
        case .nameConfirmation:
            guard flow.nameMatches(memberName) else {
                errorKey = "settings.accountDeletion.error.nameMismatch"
                return
            }
            flow.step = .finalConfirmation
        case .finalConfirmation:
            break
        }
    }

    func goBack() {
        guard !isWorking else { return }
        errorKey = nil
        switch flow.step {
        case .scope: break
        case .team: flow.step = .scope
        case .reauthentication:
            flow.clearProof()
            password = ""
            flow.step = .team
        case .nameConfirmation: flow.step = .reauthentication
        case .finalConfirmation: flow.step = .nameConfirmation
        }
    }

    func cancel() {
        flow.clearProof()
        password = ""
        errorKey = nil
    }

    func reauthenticateWithPassword() async {
        guard !password.isEmpty, !isWorking else { return }
        isWorking = true
        errorKey = nil
        defer {
            password = ""
            isWorking = false
        }
        do {
            let response = try await service.reauthenticateForAccountDeletion(password: password)
            flow.storeProof(response.reauthProof, expiresIn: response.expiresIn)
        } catch {
            flow.clearProof()
            errorKey = Self.errorKey(for: error)
        }
    }

    func reauthenticate(with provider: OAuthProvider) async {
        guard !isWorking else { return }
        isWorking = true
        errorKey = nil
        defer { isWorking = false }
        do {
            let proof = if provider == .apple {
                try await appleSignInClient.reauthenticateForAccountDeletion()
            } else {
                try await oauthClient.reauthenticateForAccountDeletion(provider: provider)
            }
            flow.storeProof(proof.value, expiresIn: proof.expiresIn)
        } catch MobileOAuthError.cancelled {
            flow.clearProof()
        } catch AppleSignInError.cancelled {
            flow.clearProof()
        } catch {
            flow.clearProof()
            errorKey = Self.errorKey(for: error)
        }
    }

    func submit() async -> AccountDeletionCompletion? {
        guard flow.step == .finalConfirmation else { return nil }
        guard !isWorking else { return nil }
        guard let proof = flow.validProof() else {
            errorKey = "settings.accountDeletion.error.proofExpired"
            flow.step = .reauthentication
            return nil
        }
        isWorking = true
        errorKey = nil
        defer {
            flow.clearProof()
            isWorking = false
        }
        do {
            _ = try await service.requestAccountDeletion(
                reauthProof: proof,
                transferAdminToMemberId: flow.selectedTransferMemberID
            )
            return .accepted
        } catch let error as APIError where Self.code(from: error) == "account.delete.alreadyPending" {
            return .alreadyPending
        } catch {
            errorKey = Self.errorKey(for: error)
            // The backend consumes a valid proof before applying later team checks,
            // so every failed final request must require a fresh proof.
            flow.step = .reauthentication
            return nil
        }
    }

    nonisolated static func errorKey(for error: Error) -> String {
        guard let apiError = error as? APIError else {
            if let appleError = error as? AppleSignInError {
                return switch appleError {
                case .configurationUnavailable:
                    "settings.accountDeletion.error.appleConfigurationUnavailable"
                case .invalidCredential, .stateMismatch:
                    "settings.accountDeletion.error.appleCredentialInvalid"
                case .providerUnavailable:
                    "settings.accountDeletion.error.appleProviderUnavailable"
                case .cancelled:
                    "settings.accountDeletion.error.reauthentication"
                }
            }
            if error is MobileOAuthError {
                return "settings.accountDeletion.error.reauthentication"
            }
            return "settings.accountDeletion.error.generic"
        }
        switch code(from: apiError) {
        case "auth.apple.configurationUnavailable":
            return "settings.accountDeletion.error.appleConfigurationUnavailable"
        case "auth.apple.credential.invalid":
            return "settings.accountDeletion.error.appleCredentialInvalid"
        case "auth.apple.provider.unavailable":
            return "settings.accountDeletion.error.appleProviderUnavailable"
        case "auth.apple.accountMismatch":
            return "settings.accountDeletion.error.appleAccountMismatch"
        case "auth.reauth.proof.invalid", "account.delete.reauthenticationFailed":
            return "settings.accountDeletion.error.reauthentication"
        case "account.delete.teamAdminTransferRequired":
            return "settings.accountDeletion.error.transferRequired"
        case "account.delete.teamAdminTransferInvalid":
            return "settings.accountDeletion.error.transferInvalid"
        case "account.delete.impersonationForbidden", "auth.reauth.impersonationForbidden":
            return "settings.accountDeletion.error.impersonation"
        case "account.delete.alreadyPending":
            return "settings.accountDeletion.error.alreadyPending"
        default:
            return "settings.accountDeletion.error.generic"
        }
    }

    nonisolated private static func code(from error: APIError) -> String? {
        switch error {
        case .server(_, let code), .serverWithDetails(_, let code, _): code
        default: nil
        }
    }

}

#if DEBUG
private nonisolated struct AccountDeletionUITestingService: AccountDeletionServicing, Sendable {
    func accountDeletionPreview() async throws -> AccountDeletionPreview {
        AccountDeletionPreview(
            hasPassword: true,
            socialProviders: [],
            teamImpact: nil,
            auxiliaryImpacts: []
        )
    }

    func reauthenticateForAccountDeletion(password: String) async throws -> AccountDeletionReauthProof {
        AccountDeletionReauthProof(reauthProof: "ui-testing-proof", expiresIn: 300)
    }

    func requestAccountDeletion(
        reauthProof: String,
        transferAdminToMemberId: Int64?
    ) async throws -> AccountDeletionAccepted {
        throw APIError.server(status: 409, code: "ui-testing.accountDeletion.executionForbidden")
    }
}
#endif

struct AccountDeletionView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = AccountDeletionViewModel()
    @ObservedObject var push: APNsRegistrationManager
    let memberName: String
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    var workingChanged: (Bool) -> Void = { _ in }
    @FocusState private var focusedField: Field?

    private enum Field { case password, name }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight, scrollTarget: focusedField) {
            header
        } content: {
            bodyContent
        } footer: {
            actions
        }
        .task { await model.load() }
        .interactiveDismissDisabled(model.isWorking)
        .onChange(of: model.isWorking) { _, isWorking in
            workingChanged(isWorking)
        }
        .onDisappear { model.cancel() }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            progress
            if model.isLoading {
                ProgressView(SettingsLocalization.string("settings.accountDeletion.loading"))
                    .frame(maxWidth: .infinity, minHeight: 180)
            } else if model.preview == nil {
                loadFailure
            } else {
                stepContent
            }
            if let errorKey = model.errorKey {
                Label(SettingsLocalization.string(errorKey), systemImage: "exclamationmark.triangle.fill")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
                    .accessibilityIdentifier("accountDeletion.error")
            }
        }
        .padding(DPSpacing.large)
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                SettingsLocalization.text("settings.accountDeletion.title")
                    .font(DPTypography.pageTitle)
                Text("\(model.flow.step.rawValue + 1) / \(AccountDeletionStep.allCases.count)")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
            }
            Spacer()
            Button {
                model.cancel()
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .disabled(model.isWorking)
            .accessibilityLabel(SettingsLocalization.text("settings.action.cancel"))
            .accessibilityIdentifier("accountDeletion.cancel")
        }
        .padding(.horizontal, DPSpacing.large)
        .padding(.vertical, DPSpacing.medium)
    }

    private var progress: some View {
        ProgressView(value: Double(model.flow.step.rawValue + 1), total: 5)
            .tint(DPColor.danger)
            .accessibilityLabel(SettingsLocalization.text("settings.accountDeletion.progress"))
            .accessibilityValue("\(model.flow.step.rawValue + 1) / 5")
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.flow.step {
        case .scope: scopeStep
        case .team: teamStep
        case .reauthentication: reauthenticationStep
        case .nameConfirmation: nameStep
        case .finalConfirmation: finalStep
        }
    }

    private var scopeStep: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            stepTitle("settings.accountDeletion.scope.title")
            SettingsLocalization.text("settings.accountDeletion.scope.message")
                .foregroundStyle(DPColor.textSecondary)
            warning("settings.accountDeletion.scope.access")
            warning("settings.accountDeletion.scope.async")
            if let auxiliaries = model.preview?.auxiliaryImpacts, !auxiliaries.isEmpty {
                SettingsLocalization.text("settings.accountDeletion.scope.auxiliary")
                    .font(DPTypography.bodyMedium)
                ForEach(auxiliaries) { account in
                    Label(account.name, systemImage: "person.crop.circle.badge.xmark")
                        .foregroundStyle(DPColor.textSecondary)
                }
            }
        }
    }

    private var teamStep: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            stepTitle("settings.accountDeletion.team.title")
            if let team = model.preview?.teamImpact {
                Label(team.teamName, systemImage: "person.3")
                    .font(DPTypography.bodyMedium)
                if team.willDeleteTeam {
                    warning("settings.accountDeletion.team.soloDelete")
                } else if team.isAdmin {
                    SettingsLocalization.text("settings.accountDeletion.team.transferRequired")
                        .foregroundStyle(DPColor.textSecondary)
                    if team.transferCandidates.isEmpty {
                        warning("settings.accountDeletion.error.noTransferCandidate")
                    } else {
                        Picker(
                            SettingsLocalization.string("settings.accountDeletion.team.successor"),
                            selection: $model.flow.selectedTransferMemberID
                        ) {
                            Text(SettingsLocalization.string("settings.accountDeletion.team.select"))
                                .tag(Int64?.none)
                            ForEach(team.transferCandidates) { candidate in
                                Text(verbatim: candidate.name).tag(Optional(candidate.memberId))
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                        .accessibilityIdentifier("accountDeletion.transferPicker")
                    }
                } else {
                    SettingsLocalization.text("settings.accountDeletion.team.memberOnly")
                        .foregroundStyle(DPColor.textSecondary)
                }
            } else {
                SettingsLocalization.text("settings.accountDeletion.team.none")
                    .foregroundStyle(DPColor.textSecondary)
            }
        }
    }

    private var reauthenticationStep: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            stepTitle("settings.accountDeletion.reauth.title")
            SettingsLocalization.text("settings.accountDeletion.reauth.message")
                .foregroundStyle(DPColor.textSecondary)
            if model.preview?.hasPassword == true {
                SecureField(
                    SettingsLocalization.string("settings.accountDeletion.reauth.password"),
                    text: $model.password
                )
                .textContentType(.password)
                .submitLabel(.done)
                .focused($focusedField, equals: .password)
                .padding(.horizontal, DPSpacing.medium)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                .accessibilityIdentifier("accountDeletion.password")
                .id(Field.password)
                Button(SettingsLocalization.string("settings.accountDeletion.reauth.passwordAction")) {
                    Task { await model.reauthenticateWithPassword() }
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(model.password.isEmpty || model.isWorking)
                .accessibilityIdentifier("accountDeletion.passwordReauth")
            }
            ForEach(model.preview?.socialProviders ?? [], id: \.rawValue) { provider in
                Button {
                    Task { await model.reauthenticate(with: provider) }
                } label: {
                    Text(SettingsSocialManagementPolicy.providerName(provider))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
                .accessibilityIdentifier("accountDeletion.social.\(provider.rawValue.lowercased())")
            }
            if model.flow.reauthProof != nil {
                Label(
                    SettingsLocalization.string("settings.accountDeletion.reauth.complete"),
                    systemImage: "checkmark.shield.fill"
                )
                .foregroundStyle(DPColor.success)
            }
        }
    }

    private var nameStep: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            stepTitle("settings.accountDeletion.name.title")
            SettingsLocalization.text("settings.accountDeletion.name.message")
                .foregroundStyle(DPColor.textSecondary)
            Text(verbatim: memberName)
                .font(DPTypography.bodyMedium)
                .textSelection(.enabled)
            TextField(
                SettingsLocalization.string("settings.accountDeletion.name.placeholder"),
                text: $model.flow.typedName
            )
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($focusedField, equals: .name)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            .accessibilityIdentifier("accountDeletion.nameConfirmation")
            .id(Field.name)
        }
    }

    private var finalStep: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            stepTitle("settings.accountDeletion.final.title")
            warning("settings.accountDeletion.final.message")
            SettingsLocalization.text("settings.accountDeletion.final.irreversible")
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.danger)
        }
    }

    private var loadFailure: some View {
        VStack(spacing: DPSpacing.medium) {
            SettingsLocalization.text("settings.accountDeletion.error.load")
                .foregroundStyle(DPColor.textSecondary)
            Button(SettingsLocalization.string("settings.action.retry")) {
                Task { await model.load() }
            }
            .buttonStyle(DPPrimaryButtonStyle())
        }
        .frame(maxWidth: .infinity, minHeight: 180)
    }

    private var actions: some View {
        HStack(spacing: DPSpacing.small) {
            if model.flow.step != .scope {
                Button {
                    model.goBack()
                } label: {
                    SettingsLocalization.text("settings.accountDeletion.back")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
                .accessibilityIdentifier("accountDeletion.back")
            }
            if model.flow.step == .finalConfirmation {
                Button {
                    Task { await deleteAccount() }
                } label: {
                    SettingsLocalization.text("settings.accountDeletion.final.action")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(model.isWorking)
                .accessibilityIdentifier("accountDeletion.submit")
            } else {
                Button {
                    model.advance(memberName: memberName)
                } label: {
                    SettingsLocalization.text("settings.accountDeletion.continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(!canAdvance || model.isWorking)
                .accessibilityIdentifier("accountDeletion.continue")
            }
        }
        .padding(DPSpacing.compact)
    }

    private var canAdvance: Bool {
        switch model.flow.step {
        case .scope: model.preview != nil
        case .team: model.canContinue
        case .reauthentication: model.canContinue
        case .nameConfirmation: model.flow.nameMatches(memberName)
        case .finalConfirmation: false
        }
    }

    private func deleteAccount() async {
        guard await model.submit() != nil else { return }
        await push.completeAccountDeletionCleanup()
        await session.completeAccountDeletion()
        dismiss()
    }

    private func stepTitle(_ key: String) -> some View {
        SettingsLocalization.text(key)
            .font(DPTypography.heading)
            .foregroundStyle(DPColor.textPrimary)
    }

    private func warning(_ key: String) -> some View {
        Label(SettingsLocalization.string(key), systemImage: "exclamationmark.triangle.fill")
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.danger)
            .padding(DPSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DPColor.dangerSoft, in: RoundedRectangle(cornerRadius: DPRadius.standard))
    }
}
