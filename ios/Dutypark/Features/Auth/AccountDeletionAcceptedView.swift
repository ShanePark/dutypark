import Combine
import Foundation
import SwiftUI

nonisolated enum AccountDeletionStatusPresentation: Equatable, Sendable {
    case processing
    case completed(completedAt: String?)
    case failed
    case expired
    case unavailable

    var isTerminal: Bool {
        switch self {
        case .processing: false
        case .completed, .failed, .expired, .unavailable: true
        }
    }

    var terminalHaptic: DPHapticKind? {
        switch self {
        case .completed: .success
        case .failed: .error
        case .processing, .expired, .unavailable: nil
        }
    }
}

@MainActor
final class AccountDeletionStatusViewModel: ObservableObject {
    @Published private(set) var presentation: AccountDeletionStatusPresentation
    @Published private(set) var isPolling = false
    @Published private(set) var isRequestInFlight = false
    @Published private(set) var lastRequestFailed = false
    @Published private(set) var terminalHaptic: DPHapticKind?

    private let receipt: AccountDeletionReceipt?
    private let service: any AccountDeletionStatusServicing
    private let pollInterval: Duration
    private let now: @MainActor @Sendable () -> Date
    private var terminalHapticEmitted = false

    init(
        receipt: AccountDeletionReceipt?,
        service: any AccountDeletionStatusServicing = SettingsService(),
        pollInterval: Duration = .seconds(5),
        now: @escaping @MainActor @Sendable () -> Date = { .now }
    ) {
        self.receipt = receipt
        self.service = service
        self.pollInterval = pollInterval
        self.now = now
        self.presentation = receipt == nil ? .expired : .processing
    }

    func start() async {
        guard !isPolling else { return }
        guard receipt != nil else {
            presentation = .expired
            return
        }

        isPolling = true
        defer { isPolling = false }

        while !Task.isCancelled && !presentation.isTerminal {
            await pollOnce()
            guard !Task.isCancelled, !presentation.isTerminal else { break }
            do {
                try await Task.sleep(for: pollInterval)
            } catch {
                break
            }
        }
    }

    /// Performs at most one request. The in-flight guard prevents a manual
    /// retry and the periodic loop from issuing duplicate status calls.
    func pollOnce() async {
        guard !isRequestInFlight,
              !presentation.isTerminal,
              let receipt
        else { return }

        isRequestInFlight = true
        defer { isRequestInFlight = false }

        do {
            let response = try await service.accountDeletionStatus(
                receiptToken: receipt.receiptToken
            )
            lastRequestFailed = false
            switch response.status.uppercased() {
            case "PROCESSING", "ACCEPTED", "PENDING":
                presentation = .processing
            case "COMPLETED":
                transition(to: .completed(completedAt: response.completedAt))
            case "FAILED":
                transition(to: .failed)
            default:
                transition(to: .unavailable)
            }
        } catch let error as APIError where Self.statusCode(of: error) == 404 {
            // A missing/expired receipt gives no evidence that deletion
            // completed. A just-created job can briefly be invisible to the
            // public endpoint, so keep polling until its provisional ETA. If
            // the ETA is absent or malformed, polling cannot be bounded and
            // the status must be surfaced as unavailable instead.
            switch Self.estimatedCompletionState(
                receipt.estimatedCompletionAt,
                at: now()
            ) {
            case .beforeEstimatedCompletion:
                lastRequestFailed = false
            case .estimatedCompletionReached:
                transition(to: .expired)
            case .invalid:
                transition(to: .unavailable)
            }
        } catch is CancellationError {
            // View task cancellation is expected when the screen disappears.
        } catch {
            // A transient status failure must not be presented as completed or
            // failed. The polling loop can retry with the same receipt token.
            lastRequestFailed = true
        }
    }

    func retryNow() async {
        guard presentation == .processing else { return }
        lastRequestFailed = false
        await pollOnce()
    }

    private func transition(to next: AccountDeletionStatusPresentation) {
        guard presentation != next else { return }
        presentation = next
        guard !terminalHapticEmitted, let haptic = next.terminalHaptic else { return }
        terminalHapticEmitted = true
        terminalHaptic = haptic
        DPHapticCenter.shared.emit(haptic)
    }

    private static func statusCode(of error: APIError) -> Int? {
        switch error {
        case .server(let status, _), .serverWithDetails(let status, _, _): status
        default: nil
        }
    }

    private enum EstimatedCompletionState {
        case beforeEstimatedCompletion
        case estimatedCompletionReached
        case invalid
    }

    private static func estimatedCompletionState(
        _ estimatedCompletionAt: String,
        at now: Date
    ) -> EstimatedCompletionState {
        guard let estimatedDate = SettingsSessionFormatter.date(from: estimatedCompletionAt) else {
            return .invalid
        }
        return now >= estimatedDate
            ? .estimatedCompletionReached
            : .beforeEstimatedCompletion
    }
}

struct AccountDeletionAcceptedView: View {
    let onDismiss: (Bool) -> Void
    let onOpenSupport: () -> Void

    @StateObject private var model: AccountDeletionStatusViewModel

    init(
        receipt: AccountDeletionReceipt?,
        onDismiss: @escaping (Bool) -> Void,
        onOpenSupport: @escaping () -> Void,
        service: any AccountDeletionStatusServicing = SettingsService()
    ) {
        self.onDismiss = onDismiss
        self.onOpenSupport = onOpenSupport
        _model = StateObject(wrappedValue: AccountDeletionStatusViewModel(
            receipt: receipt,
            service: service
        ))
    }

    /// Compatibility initializer for previews and older callers that only need
    /// a static accepted screen.
    init(onConfirm: @escaping () -> Void) {
        self.init(
            receipt: nil,
            onDismiss: { _ in onConfirm() },
            onOpenSupport: {}
        )
    }

    var body: some View {
        GeometryReader { geometry in
            ScrollView {
                VStack(spacing: DPSpacing.large) {
                    Spacer(minLength: DPSpacing.large)
                    hero
                    content
                }
                .frame(maxWidth: 560)
                .frame(minHeight: max(0, geometry.size.height - 96))
                .padding(.horizontal, DPSpacing.large)
                .padding(.bottom, DPSpacing.large)
                .frame(maxWidth: .infinity)
            }
            .safeAreaInset(edge: .bottom) {
                actions
            }
        }
        .background(DPColor.backgroundPrimary.ignoresSafeArea())
        .task { await model.start() }
        .accessibilityIdentifier("screen.accountDeletionAccepted")
    }

    private var hero: some View {
        VStack(spacing: DPSpacing.medium) {
            Image(systemName: iconName)
                .font(.system(size: 56))
                .foregroundStyle(iconColor)
                .accessibilityHidden(true)

            Text(title)
                .font(DPTypography.pageTitle)
                .foregroundStyle(DPColor.textPrimary)
                .multilineTextAlignment(.center)
                .accessibilityIdentifier("accountDeletion.accepted.title")

            Text(message)
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var content: some View {
        switch model.presentation {
        case .processing:
            processingContent
        case .completed:
            terminalCard(
                systemImage: "checkmark.circle.fill",
                textKey: "settings.accountDeletion.completed.details",
                identifier: "accountDeletion.accepted.completed"
            )
        case .failed:
            terminalCard(
                systemImage: "exclamationmark.triangle.fill",
                textKey: "settings.accountDeletion.failed.details",
                identifier: "accountDeletion.accepted.failed"
            )
        case .expired:
            terminalCard(
                systemImage: "questionmark.circle",
                textKey: "settings.accountDeletion.expired.details",
                identifier: "accountDeletion.accepted.expired"
            )
        case .unavailable:
            terminalCard(
                systemImage: "questionmark.circle",
                textKey: "settings.accountDeletion.unavailable.details",
                identifier: "accountDeletion.accepted.unavailable"
            )
        }
    }

    private var processingContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            informationRow(
                systemImage: "clock.arrow.circlepath",
                text: SettingsLocalization.string("settings.accountDeletion.accepted.eta")
            )
            Divider().overlay(DPColor.borderPrimary)
            informationRow(
                systemImage: "checkmark.circle",
                text: SettingsLocalization.string("settings.accountDeletion.accepted.processing")
            )
            if model.lastRequestFailed {
                Label(
                    SettingsLocalization.string("settings.accountDeletion.accepted.statusUnavailable"),
                    systemImage: "wifi.exclamationmark"
                )
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.warning)
                .accessibilityIdentifier("accountDeletion.accepted.statusUnavailable")

                Button(SettingsLocalization.string("settings.accountDeletion.accepted.retry")) {
                    Task { await model.retryNow() }
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isRequestInFlight)
                .accessibilityIdentifier("accountDeletion.accepted.retry")
            }
        }
        .dpCard(padding: DPSpacing.medium)
        .accessibilityIdentifier("accountDeletion.accepted.processing")
    }

    private func terminalCard(
        systemImage: String,
        textKey: String,
        identifier: String
    ) -> some View {
        Label {
            Text(SettingsLocalization.string(textKey))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(terminalColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .accessibilityIdentifier(identifier)
    }

    @ViewBuilder
    private var actions: some View {
        if model.presentation != .processing {
            HStack(spacing: DPSpacing.small) {
                if model.presentation == .failed || model.presentation == .expired || model.presentation == .unavailable {
                    Button {
                        onOpenSupport()
                    } label: {
                        Text(SettingsLocalization.string("settings.accountDeletion.accepted.support"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                    .accessibilityIdentifier("accountDeletion.accepted.support")
                }

                Button {
                    onDismiss(shouldClearReceipt)
                } label: {
                    Text(SettingsLocalization.string(actionKey))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .accessibilityIdentifier("accountDeletion.accepted.dismiss")
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.vertical, DPSpacing.medium)
            .background(DPColor.backgroundPrimary)
        }
    }

    private var shouldClearReceipt: Bool {
        switch model.presentation {
        case .processing: false
        case .completed, .failed, .expired, .unavailable: true
        }
    }

    private var iconName: String {
        switch model.presentation {
        case .processing: "clock.badge.checkmark"
        case .completed: "checkmark.shield.fill"
        case .failed: "exclamationmark.triangle.fill"
        case .expired, .unavailable: "questionmark.circle.fill"
        }
    }

    private var iconColor: Color {
        switch model.presentation {
        case .processing: DPColor.accent
        case .completed: DPColor.success
        case .failed: DPColor.danger
        case .expired, .unavailable: DPColor.warning
        }
    }

    private var terminalColor: Color {
        switch model.presentation {
        case .completed: DPColor.success
        case .failed: DPColor.danger
        case .processing, .expired, .unavailable: DPColor.warning
        }
    }

    private var title: String {
        switch model.presentation {
        case .processing: SettingsLocalization.string("settings.accountDeletion.accepted.title")
        case .completed: SettingsLocalization.string("settings.accountDeletion.completed.title")
        case .failed: SettingsLocalization.string("settings.accountDeletion.failed.title")
        case .expired: SettingsLocalization.string("settings.accountDeletion.expired.title")
        case .unavailable: SettingsLocalization.string("settings.accountDeletion.unavailable.title")
        }
    }

    private var message: String {
        switch model.presentation {
        case .processing: SettingsLocalization.string("settings.accountDeletion.accepted.loggedOut")
        case .completed: SettingsLocalization.string("settings.accountDeletion.completed.message")
        case .failed: SettingsLocalization.string("settings.accountDeletion.failed.message")
        case .expired: SettingsLocalization.string("settings.accountDeletion.expired.message")
        case .unavailable: SettingsLocalization.string("settings.accountDeletion.unavailable.message")
        }
    }

    private var actionKey: String {
        switch model.presentation {
        case .processing: "settings.accountDeletion.accepted.dismiss"
        case .completed: "settings.accountDeletion.completed.confirm"
        case .failed, .expired, .unavailable: "settings.accountDeletion.accepted.dismiss"
        }
    }

    private func informationRow(systemImage: String, text: String) -> some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            Image(systemName: systemImage)
                .font(.system(size: DPSize.icon))
                .foregroundStyle(DPColor.accent)
                .frame(width: DPSize.iconLarge)
                .accessibilityHidden(true)

            Text(text)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}
