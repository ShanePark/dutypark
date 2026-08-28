import SwiftUI
import UIKit
import UserNotifications

nonisolated enum SettingsDestination: Hashable, Sendable {
    case guide
    case terms
    case privacy
}

nonisolated enum SettingsDeepLink {
    static func destination(from url: URL, allowedHost: String = "dutypark.o-r.kr") -> SettingsDestination? {
        guard url.scheme?.lowercased() == "https",
              url.host?.lowercased() == allowedHost.lowercased()
        else { return nil }

        switch url.pathComponents.filter({ $0 != "/" }) {
        case ["guide"]: return SettingsDestination.guide
        case ["terms"]: return SettingsDestination.terms
        case ["privacy"]: return SettingsDestination.privacy
        default: return nil
        }
    }
}

/// App preferences that are not tied to the account identity. The account sections
/// live in `MyInfoView`.
struct SettingsView: View {
    @StateObject private var model = SettingsViewModel()
    @StateObject private var push = APNsRegistrationManager.shared
    @StateObject private var aiConsent = AIScheduleParsingConsentStore.shared
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme
    @Environment(\.openURL) private var openURL
    @State private var showVisibility = false
    @State private var showAIConsentConfirmation = false
    @Binding private var destination: SettingsDestination?

    init(destination: Binding<SettingsDestination?> = .constant(nil)) {
        _destination = destination
    }

    var body: some View {
        Group {
            if model.member == nil, model.isLoading || !model.didAttemptMemberLoad {
                ProgressView(SettingsLocalization.string("settings.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if model.member == nil {
                ContentUnavailableView {
                    Label(
                        SettingsLocalization.string("settings.error.load"),
                        systemImage: "exclamationmark.triangle"
                    )
                } actions: {
                    Button(SettingsLocalization.string("settings.action.retry")) {
                        Task { await model.load(.settings) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DPSpacing.medium) {
                        visibilitySection
                        appearanceSection
                        pushSection
                        aiConsentSection
                        informationSection
                    }
                    .padding(.horizontal, DPSpacing.medium)
                    .padding(.top, DPSpacing.large)
                    .padding(.bottom, DPSpacing.extraLarge)
                }
                .background(DPColor.backgroundSecondary)
                .refreshable { await model.load(.settings) }
            }
        }
        .accessibilityIdentifier("screen.settings")
        .task {
            await model.load(.settings)
#if DEBUG
            let arguments = ProcessInfo.processInfo.arguments
            if arguments.contains("-ui-testing-long-form-policy-terms") {
                destination = .terms
            } else if arguments.contains("-ui-testing-long-form-policy-privacy") {
                destination = .privacy
            }
#endif
        }
        .task { await push.resumeRegistration() }
        .task(id: model.member?.id) {
            guard let memberID = model.member?.id else { return }
            await aiConsent.load(for: memberID)
        }
        .fullScreenCover(isPresented: $showVisibility) {
            DPModalOverlay(
                onDismiss: { showVisibility = false },
                closeOnBackdrop: !model.isWorking,
                canDismiss: !model.isWorking
            ) { availableSize, dismiss in
                VisibilitySettingsModal(
                    model: model,
                    maximumHeight: availableSize.height,
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $showAIConsentConfirmation) {
            if let memberID = model.member?.id {
                DPModalOverlay(
                    onDismiss: { showAIConsentConfirmation = false },
                    canDismiss: !aiConsent.isUpdating
                ) { availableSize, dismiss in
                    AIScheduleConsentActivationModal(
                        store: aiConsent,
                        memberID: memberID,
                        maximumHeight: availableSize.height,
                        dismiss: dismiss
                    )
                }
            }
        }
        .alert(SettingsLocalization.string("settings.notice.title"), isPresented: noticeBinding) {
            Button(SettingsLocalization.string("settings.action.confirm")) {
                model.noticeKey = nil
            }
        } message: {
            if let key = model.noticeKey {
                SettingsLocalization.text(key)
            }
        }
        .alert(SettingsLocalization.string("settings.notice.title"), isPresented: aiConsentErrorBinding) {
            Button(SettingsLocalization.string("settings.action.confirm")) {
                aiConsent.dismissError()
            }
        } message: {
            if let key = aiConsent.errorKey {
                SettingsLocalization.text(key)
            }
        }
        .disabled(model.isWorking)
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .guide:
                PublicGuideView()
            case .terms:
                DeepLinkedPolicyView(type: .terms, model: model)
            case .privacy:
                DeepLinkedPolicyView(type: .privacy, model: model)
            }
        }
    }

    private var visibilitySection: some View {
        SettingsCard(title: "settings.visibility.title", icon: "eye") {
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                SettingsLocalization.text("settings.visibility.current")
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                SettingsLocalization.text("settings.visibility.description")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
            }
            Button {
                DPHapticCenter.shared.emit(.routine)
                withoutPresentationAnimation { showVisibility = true }
            } label: {
                HStack(spacing: DPSpacing.small) {
                    Circle()
                        .fill(visibilityColor(model.member?.calendarVisibility ?? .friends))
                        .frame(width: 8, height: 8)
                    SettingsLocalization.text(visibilityLabelKey(model.member?.calendarVisibility ?? .friends))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .padding(.horizontal, DPSpacing.medium)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            .buttonStyle(.plain)
        }
    }

    private var appearanceSection: some View {
        SettingsCard(title: "settings.appearance.title", icon: "sun.max") {
            Picker(
                SettingsLocalization.string("settings.theme"),
                selection: themeSelection
            ) {
                ForEach(AppTheme.allCases) { theme in
                    SettingsLocalization.text(theme.titleKey)
                        .tag(theme)
                }
            }
            .pickerStyle(.segmented)
            .accessibilityLabel(SettingsLocalization.string("settings.theme"))
            .accessibilityValue(SettingsLocalization.string(selectedTheme.currentDescriptionKey))

            SettingsLocalization.text(selectedTheme.currentDescriptionKey)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textMuted)
        }
    }

    private var selectedTheme: AppTheme {
        AppTheme(rawValue: themeCode) ?? .system
    }

    private var themeSelection: Binding<AppTheme> {
        Binding(
            get: { selectedTheme },
            set: {
                guard selectedTheme != $0 else { return }
                themeCode = $0.rawValue
                DPHapticCenter.shared.emit(.selection)
            }
        )
    }

    private var pushSection: some View {
        SettingsCard(title: "settings.push.title", icon: "bell") {
            Button {
                DPHapticCenter.shared.emit(.selection)
                pushBinding.wrappedValue.toggle()
            } label: {
                HStack(spacing: DPSpacing.medium) {
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        SettingsLocalization.text("settings.push.toggle")
                            .font(DPTypography.bodyMedium)
                            .foregroundStyle(DPColor.textPrimary)
                        SettingsLocalization.text("settings.push.description")
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                            .multilineTextAlignment(.leading)
                    }
                    Spacer(minLength: DPSpacing.small)
                    SettingsSwitch(isOn: push.isToggleOn)
                }
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(push.authorizationStatus == .denied)
            .accessibilityValue(SettingsLocalization.string(push.isToggleOn ? "settings.accessibility.on" : "settings.accessibility.off"))
            .accessibilityAddTraits(.isButton)
            if push.authorizationStatus == .denied {
                Label(SettingsLocalization.string("settings.push.denied"), systemImage: "info.circle")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.warning)
            } else if push.registrationState == .unsupported {
                Label(SettingsLocalization.string("settings.push.unavailable"), systemImage: "iphone.slash")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.warning)
            } else if push.registrationState == .failed {
                Label(SettingsLocalization.string("settings.push.failed"), systemImage: "exclamationmark.triangle")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
            }
        }
    }

    private var aiConsentSection: some View {
        SettingsCard(title: "settings.aiConsent.title", icon: "sparkles") {
            Button(action: toggleAIConsent) {
                HStack(spacing: DPSpacing.medium) {
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        SettingsLocalization.text("settings.aiConsent.toggle")
                            .font(DPTypography.bodyMedium)
                            .foregroundStyle(DPColor.textPrimary)
                        SettingsLocalization.text("settings.aiConsent.description")
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                            .multilineTextAlignment(.leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: DPSpacing.small)
                    if aiConsent.isLoading || aiConsent.isUpdating {
                        ProgressView()
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                            .accessibilityLabel(SettingsLocalization.string("settings.aiConsent.updating"))
                    } else {
                        SettingsSwitch(isOn: aiConsent.isEnabled)
                    }
                }
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(aiConsent.isLoading || aiConsent.isUpdating || aiConsent.response == nil)
            .accessibilityLabel(SettingsLocalization.string("settings.aiConsent.toggle"))
            .accessibilityValue(SettingsLocalization.string(
                aiConsent.isEnabled ? "settings.accessibility.on" : "settings.accessibility.off"
            ))
            .accessibilityAddTraits(.isButton)

            SettingsLocalization.text("settings.aiConsent.dataFlow")
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if aiConsent.response?.needsRenewal == true {
                Label(SettingsLocalization.string("settings.aiConsent.renewalRequired"), systemImage: "exclamationmark.circle")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.warning)
            }

            if aiConsent.response == nil, !aiConsent.isLoading {
                Button(SettingsLocalization.string("settings.action.retry")) {
                    guard let memberID = model.member?.id else { return }
                    Task { await aiConsent.load(for: memberID, force: true) }
                }
                .buttonStyle(DPOutlineButtonStyle())
            }

            settingsNavigationLink("settings.aiConsent.policy", icon: "doc.text") {
                AIScheduleConsentPolicyView(
                    store: aiConsent,
                    memberID: model.member?.id
                )
            }
        }
    }

    private var informationSection: some View {
        SettingsCard(title: "settings.information.title", icon: "info.circle") {
            languageRow
            if model.loadedSections.contains(.policies) {
                settingsNavigationLink("settings.policy.terms") {
                    PolicyView(titleKey: "settings.policy.terms", policy: model.policies?.terms)
                }
                settingsNavigationLink("settings.policy.privacy") {
                    PolicyView(titleKey: "settings.policy.privacy", policy: model.policies?.privacy)
                }
            }
            if model.policyLoadFailed {
                VStack(alignment: .leading, spacing: 8) {
                    Label(
                        SettingsLocalization.string("settings.policy.loadError"),
                        systemImage: "exclamationmark.triangle"
                    )
                    .foregroundStyle(.secondary)
                    Button(SettingsLocalization.string("settings.action.retry")) {
                        Task { await model.reloadPolicies() }
                    }
                    .frame(minHeight: 44)
                }
            }
            settingsNavigationLink("settings.guide", icon: "book") {
                PublicGuideView()
            }
            settingsNavigationLink("settings.releaseNotes", icon: "clock.arrow.circlepath") {
                PublicReleaseNotesView()
            }
        }
    }

    private var visibilityBinding: Binding<Visibility> {
        Binding(
            get: { model.member?.calendarVisibility ?? .friends },
            set: { value in
                guard model.member?.calendarVisibility != value else { return }
                DPHapticCenter.shared.emit(.selection)
                Task { await model.updateVisibility(value) }
            }
        )
    }

    private var pushBinding: Binding<Bool> {
        Binding(
            // Use the persisted preference for tap intent. `isToggleOn` is the
            // effective display state and is off after a registration failure;
            // using it here would make the first tap retry instead of disabling
            // the failed setting.
            get: { push.isUserPreferenceOn },
            set: { enabled in
                if enabled {
                    push.requestPermission()
                } else {
                    push.setEnabled(false)
                    Task { await push.unregister() }
                }
            }
        )
    }

    private var aiConsentErrorBinding: Binding<Bool> {
        Binding(
            get: { aiConsent.errorKey != nil && !showAIConsentConfirmation },
            set: { if !$0 { aiConsent.dismissError() } }
        )
    }

    private func toggleAIConsent() {
        guard let memberID = model.member?.id else { return }
        if aiConsent.isEnabled {
            DPHapticCenter.shared.emit(.selection)
            Task { _ = await aiConsent.revoke(for: memberID) }
            return
        }

        switch AIScheduleConsentSettingsActivationPolicy.decision(response: aiConsent.response) {
        case .showAgreement:
            aiConsent.dismissError()
            showAIConsentConfirmation = true
        case let .grant(policyVersion):
            aiConsent.dismissError()
            DPHapticCenter.shared.emit(.selection)
            Task {
                _ = await aiConsent.grant(for: memberID, policyVersion: policyVersion)
            }
        case .unavailable:
            aiConsent.reportLoadFailure()
            DPHapticCenter.shared.emit(.warning)
        }
    }

    /// iOS owns the per-app language, so this row mirrors the resolved language and
    /// hands the change off to Settings instead of keeping a second source of truth.
    private var languageRow: some View {
        Button {
            guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
            openURL(url)
        } label: {
            HStack(spacing: DPSpacing.medium) {
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    SettingsLocalization.text("settings.language")
                        .font(DPTypography.bodyMedium)
                        .foregroundStyle(DPColor.textPrimary)
                    SettingsLocalization.text("settings.language.systemHint")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: DPSpacing.small)
                Text(verbatim: AppLanguage.current.nativeName)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textSecondary)
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
            }
            .frame(minHeight: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            DPHapticCenter.shared.emit(.routine)
        })
        .accessibilityIdentifier("settings.language")
    }

    private var noticeBinding: Binding<Bool> {
        Binding(
            get: { model.noticeKey != nil },
            set: {
                if !$0 {
                    model.noticeKey = nil
                }
            }
        )
    }

    private func visibilityAudience(
        title: String,
        emptyKey: String,
        people: [FriendDTO]
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                SettingsLocalization.text(title)
                Text("\(people.count)")
            }
            if people.isEmpty {
                SettingsLocalization.text(emptyKey).foregroundStyle(DPColor.warning)
            } else {
                let visibleNames = people.prefix(3).map(\.name).joined(separator: ", ")
                let remaining = max(0, people.count - 3)
                Text(remaining > 0 ? "\(visibleNames) +\(remaining)" : visibleNames)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
            }
        }
        .font(.caption)
    }

    private func settingsNavigationLink<Destination: View>(
        _ titleKey: String,
        icon: String? = nil,
        @ViewBuilder destination: () -> Destination
    ) -> some View {
        NavigationLink(destination: destination) {
            HStack(spacing: DPSpacing.small) {
                if let icon { Image(systemName: icon) }
                SettingsLocalization.text(titleKey)
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
            }
            .font(DPTypography.body)
            .foregroundStyle(DPColor.textPrimary)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(TapGesture().onEnded {
            DPHapticCenter.shared.emit(.routine)
        })
    }

    private func visibilityLabelKey(_ visibility: Visibility) -> String {
        switch visibility {
        case .publicAccess: "settings.visibility.public"
        case .friends: "settings.visibility.friends"
        case .family: "settings.visibility.family"
        case .privateAccess: "settings.visibility.private"
        case .unknown: "settings.visibility.friends"
        }
    }

    private func visibilityColor(_ visibility: Visibility) -> Color {
        switch visibility {
        case .publicAccess: DPColor.success
        case .friends: DPColor.accent
        case .family: DPColor.warning
        case .privateAccess: DPColor.danger
        case .unknown: DPColor.accent
        }
    }

}

nonisolated struct SettingsDestructiveActionGate: Equatable, Sendable {
    private(set) var isWorking = false

    mutating func start() -> Bool {
        guard !isWorking else { return false }
        isWorking = true
        return true
    }

    mutating func finish() {
        isWorking = false
    }
}

nonisolated enum SettingsSocialUnlinkPolicy {
    static func canUnlink(connectedProviderCount: Int) -> Bool {
        connectedProviderCount >= 2
    }

    static func managementDescription(for provider: OAuthProvider, locale: Locale? = nil) -> String {
        switch provider {
        case .apple:
            SettingsLocalization.string("settings.social.unlinkAppleDescription", locale: locale)
        case .kakao, .naver:
            localOnlyMessage(for: provider, locale: locale)
        }
    }

    static func confirmationMessage(for provider: OAuthProvider, locale: Locale? = nil) -> String {
        if provider == .apple {
            return SettingsLocalization.string(
                "settings.social.unlinkAppleConfirmMessage",
                locale: locale
            )
        }
        return localOnlyMessage(for: provider, locale: locale)
    }

    private static func localOnlyMessage(for provider: OAuthProvider, locale: Locale?) -> String {
        SettingsLocalization.string("settings.social.unlinkConfirmMessage", locale: locale)
            .replacingOccurrences(of: "{provider}", with: providerName(provider, locale: locale))
    }

    static func noticeKey(for error: Error) -> String {
        let status: Int?
        let code: String?
        switch error {
        case APIError.server(let value, let errorCode):
            status = value
            code = errorCode
        case APIError.serverWithDetails(let value, let errorCode, _):
            status = value
            code = errorCode
        default:
            status = nil
            code = nil
        }

        if code == "member.social.unlink.lastAuthenticationMethod" {
            return "settings.social.unlinkLastAuthenticationMethod"
        }
        if status == 403 {
            return "settings.social.unlinkImpersonationForbidden"
        }
        return "settings.social.unlinkFailed"
    }

    private static func providerName(_ provider: OAuthProvider, locale: Locale?) -> String {
        switch provider {
        case .kakao: "Kakao"
        case .naver: "Naver"
        case .apple: SettingsLocalization.string("settings.social.apple", locale: locale)
        }
    }
}

nonisolated enum SettingsSessionFormatter {
    static func sorted(_ sessions: [SettingsRefreshToken]) -> [SettingsRefreshToken] {
        sessions.sorted { lhs, rhs in
            let lhsIsCurrent = lhs.isCurrentLogin == true
            let rhsIsCurrent = rhs.isCurrentLogin == true
            if lhsIsCurrent != rhsIsCurrent { return lhsIsCurrent }
            let lhsDate = date(from: lhs.lastUsed) ?? .distantPast
            let rhsDate = date(from: rhs.lastUsed) ?? .distantPast
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return lhs.id < rhs.id
        }
    }

    static func relativeTime(_ value: String?, now: Date = Date()) -> String {
        guard let date = date(from: value) else { return "-" }
        let elapsed = now.timeIntervalSince(date)
        if elapsed >= 0, elapsed < 60 {
            return SettingsLocalization.string("settings.sessions.justNow")
        }

        let formatter = RelativeDateTimeFormatter()
        formatter.locale = AppLocalization.locale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric

        if abs(elapsed) < 3_600 {
            let minutes = signedUnit(elapsed, divisor: 60)
            return formatter.localizedString(from: DateComponents(minute: minutes))
        }
        if abs(elapsed) < 86_400 {
            let hours = signedUnit(elapsed, divisor: 3_600)
            return formatter.localizedString(from: DateComponents(hour: hours))
        }
        if abs(elapsed) < 604_800 {
            let days = signedUnit(elapsed, divisor: 86_400)
            return formatter.localizedString(from: DateComponents(day: days))
        }
        return dateText(value)
    }

    static func dateText(_ value: String?) -> String {
        guard let date = date(from: value) else { return "-" }
        let formatter = DateFormatter()
        formatter.locale = AppLocalization.locale
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    static func date(from value: String?) -> Date? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }

        let fractionalISO = ISO8601DateFormatter()
        fractionalISO.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractionalISO.date(from: value) { return date }

        let standardISO = ISO8601DateFormatter()
        standardISO.formatOptions = [.withInternetDateTime]
        if let date = standardISO.date(from: value) { return date }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        for format in [
            "yyyy-MM-dd'T'HH:mm:ss.SSSSSSSSS",
            "yyyy-MM-dd'T'HH:mm:ss.SSS",
            "yyyy-MM-dd'T'HH:mm:ss",
            "yyyy-MM-dd",
        ] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return nil
    }

    private static func signedUnit(_ elapsed: TimeInterval, divisor: TimeInterval) -> Int {
        let magnitude = max(1, Int(floor(abs(elapsed) / divisor)))
        return elapsed >= 0 ? -magnitude : magnitude
    }
}

enum SettingsConfirmation: Identifiable {
    case deleteProfilePhoto
    case removeManager(id: MemberID, name: String)
    case switchManagedAccount(id: MemberID, name: String)
    case session(SettingsSessionConfirmation)

    var id: String {
        switch self {
        case .deleteProfilePhoto: "delete-profile-photo"
        case .removeManager(let id, _): "remove-manager-\(id)"
        case .switchManagedAccount(let id, _): "switch-managed-account-\(id)"
        case .session(let confirmation): confirmation.id
        }
    }

    var titleKey: String {
        switch self {
        case .deleteProfilePhoto: "settings.photo.delete"
        case .removeManager: "settings.manager.removeTitle"
        case .switchManagedAccount: "settings.managed.switch"
        case .session(let confirmation): confirmation.titleKey
        }
    }

    var confirmTitleKey: String {
        switch self {
        case .deleteProfilePhoto: "settings.photo.delete"
        case .removeManager: "settings.manager.remove"
        case .switchManagedAccount: "settings.managed.switch"
        case .session(.session): "settings.sessions.revoke"
        case .session(.otherSessions): "settings.sessions.revokeOthers"
        }
    }

    var message: String {
        switch self {
        case .deleteProfilePhoto:
            SettingsLocalization.string("settings.photo.deleteConfirm")
        case .removeManager(_, let name):
            SettingsLocalization.string("settings.manager.removeMessage")
                .replacingOccurrences(of: "{name}", with: name)
        case .switchManagedAccount(_, let name):
            SettingsLocalization.string("settings.managed.switchMessage")
                .replacingOccurrences(of: "{name}", with: name)
        case .session(let confirmation):
            confirmation.message
        }
    }

    var isDestructive: Bool {
        switch self {
        case .switchManagedAccount: false
        case .deleteProfilePhoto, .removeManager, .session: true
        }
    }

    var requiresWarning: Bool {
        false
    }
}

enum SettingsSessionConfirmation: Identifiable {
    case session(SettingsRefreshToken)
    case otherSessions(count: Int)

    var id: String {
        switch self {
        case .session(let token): "session-\(token.id)"
        case .otherSessions(let count): "others-\(count)"
        }
    }

    var titleKey: String {
        switch self {
        case .session: "settings.sessions.revokeTitle"
        case .otherSessions: "settings.sessions.revokeOthersTitle"
        }
    }

    var message: String {
        switch self {
        case .session(let token):
            SettingsLocalization.string("settings.sessions.revokeMessage")
                .replacingOccurrences(of: "{device}", with: token.userAgent?.device ?? "-")
                .replacingOccurrences(
                    of: "{browser}",
                    with: SettingsSessionClientPresentation(token: token).clientValue
                )
                .replacingOccurrences(of: "{ip}", with: token.remoteAddr ?? "-")
        case .otherSessions(let count):
            SettingsLocalization.string("settings.sessions.revokeOthersMessage")
                .replacingOccurrences(of: "{count}", with: "\(count)")
        }
    }
}

/// Native app sessions must not read as a browser named "Dutypark", so they replace the browser row
/// with an app row instead of only swapping its value.
nonisolated struct SettingsSessionClientPresentation: Equatable, Sendable {
    let deviceIcon: String
    let clientLabelKey: String
    let clientIcon: String
    let clientValue: String

    init(token: SettingsRefreshToken) {
        if token.resolvedClientType == .iosApp {
            deviceIcon = "iphone"
            clientLabelKey = "settings.sessions.appLabel"
            clientIcon = "apps.iphone"
            clientValue = SettingsLocalization.string("settings.sessions.client.iosApp")
        } else {
            let device = token.userAgent?.device.lowercased() ?? ""
            let desktopTerms = ["other", "desktop", "mac", "windows", "linux"]
            deviceIcon = desktopTerms.contains(where: device.contains) ? "desktopcomputer" : "iphone"
            clientLabelKey = "settings.sessions.browserLabel"
            clientIcon = "globe"
            clientValue = Self.nonempty(token.userAgent?.browser)
        }
    }

    static func nonempty(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "-"
        }
        return value
    }
}

struct SettingsCard<Content: View>: View {
    let title: String
    let icon: String
    @ViewBuilder let content: Content

    init(title: String, icon: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.icon = icon
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            Label(SettingsLocalization.string(title), systemImage: icon)
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .symbolRenderingMode(.monochrome)
            content
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dpCard(padding: DPSpacing.large)
    }
}

struct SettingsSwitch: View {
    let isOn: Bool

    var body: some View {
        Capsule()
            .fill(isOn ? DPColor.accent : DPColor.borderSecondary)
            .frame(width: 48, height: 28)
            .overlay(alignment: isOn ? .trailing : .leading) {
                Circle()
                    .fill(DPColor.textOnDark)
                    .frame(width: 20, height: 20)
                    .padding(4)
                    .shadow(color: .black.opacity(0.12), radius: 1, y: 1)
            }
            .animation(.easeOut(duration: 0.2), value: isOn)
            .accessibilityHidden(true)
    }
}

struct AccentSoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.accent)
            .padding(.horizontal, DPSpacing.compact)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(configuration.isPressed ? DPColor.accentSoftHover : DPColor.accentSoft)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
    }
}

struct DangerSoftButtonStyle: ButtonStyle {
    @Environment(\.isEnabled) private var isEnabled
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.danger)
            .padding(.horizontal, DPSpacing.compact)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(configuration.isPressed ? DPColor.dangerSoftHover : DPColor.dangerSoft)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
    }
}

struct SettingsModalHeader: View {
    let titleKey: String
    var closeDisabled = false
    let close: () -> Void

    var body: some View {
        HStack {
            SettingsLocalization.text(titleKey)
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: 44, height: 44)
                    .background(DPColor.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(closeDisabled)
            .accessibilityLabel(SettingsLocalization.string("settings.action.cancel"))
        }
        .padding(.horizontal, DPSpacing.large)
        .frame(minHeight: 64)
    }
}

/// Footer row for `DPModalPanel`. The panel draws the separating divider and
/// `DPModalOverlay` paints the modal background behind it.
struct SettingsModalActions<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        HStack(spacing: DPSpacing.small) { content }
            .padding(DPSpacing.compact)
    }
}

private struct VisibilitySettingsModal: View {
    @ObservedObject var model: SettingsViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    private let options: [Visibility] = [.publicAccess, .friends, .family, .privateAccess]

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            SettingsModalHeader(
                titleKey: "settings.visibility.modalTitle",
                closeDisabled: model.isWorking,
                close: dismiss
            )
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button(action: dismiss) {
                    SettingsLocalization.text("settings.visibility.close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
            }
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            SettingsLocalization.text("settings.visibility.modalDescription")
                .font(DPTypography.body)
                .foregroundStyle(DPColor.textSecondary)
            SettingsLocalization.text("settings.visibility.modalHint")
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textMuted)
            ForEach(options, id: \.rawValue) { option in
                visibilityOption(option)
            }
        }
        .padding(DPSpacing.large)
    }

    private func visibilityOption(_ option: Visibility) -> some View {
        let selected = model.member?.calendarVisibility == option
        let audience = option == .friends ? model.friends : option == .family ? model.friends.filter(\.isFamily) : []
        return Button {
            if model.member?.calendarVisibility != option {
                DPHapticCenter.shared.emit(.selection)
            }
            Task {
                await model.updateVisibility(option)
                if model.member?.calendarVisibility == option { dismiss() }
            }
        } label: {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack(spacing: DPSpacing.compact) {
                    Circle().fill(optionColor(option)).frame(width: 12, height: 12)
                    SettingsLocalization.text(optionLabel(option))
                        .font(DPTypography.bodyMedium)
                        .foregroundStyle(DPColor.textPrimary)
                    Spacer()
                    if selected { Image(systemName: "checkmark").foregroundStyle(DPColor.accent) }
                }
                SettingsLocalization.text(optionDescription(option))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(.leading, DPSpacing.large)
                if option == .friends || option == .family {
                    Text(audience.isEmpty
                         ? SettingsLocalization.string(option == .friends ? "settings.visibility.emptyFriends" : "settings.visibility.emptyFamily")
                         : audience.prefix(3).map(\.name).joined(separator: ", ") + (audience.count > 3 ? " +\(audience.count - 3)" : ""))
                        .font(DPTypography.caption)
                        .foregroundStyle(audience.isEmpty ? DPColor.warning : DPColor.textMuted)
                        .padding(.leading, DPSpacing.large)
                        .lineLimit(1)
                }
            }
            .padding(DPSpacing.medium)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(selected ? DPColor.accentSoft : DPColor.backgroundSecondary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(selected ? DPColor.accent : DPColor.borderPrimary, lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(model.isWorking)
    }
}

private struct PolicyView: View {
    let titleKey: String
    let policy: PolicyDTO?

    var body: some View {
        ScrollView {
            if let policy {
                VStack(alignment: .leading, spacing: 16) {
                    DPLongFormDocument(content: policy.content)
                    Divider()
                    Text("\(policy.version) · \(policy.effectiveDate.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, DPLongFormDocumentLayout.horizontalPadding)
                .padding(.vertical, DPLongFormDocumentLayout.verticalPadding)
            } else {
                ContentUnavailableView(
                    SettingsLocalization.string("settings.policy.unavailable"),
                    systemImage: "doc.text"
                )
            }
        }
        .navigationTitle(SettingsLocalization.string(titleKey))
        .navigationBarTitleDisplayMode(.inline)
    }
}

nonisolated enum AIScheduleConsentSettingsActivationDecision: Equatable, Sendable {
    case showAgreement
    case grant(policyVersion: String)
    case unavailable
}

nonisolated enum AIScheduleConsentSettingsActivationPolicy {
    static func decision(
        response: AIScheduleParsingConsentResponse?
    ) -> AIScheduleConsentSettingsActivationDecision {
        guard let response else { return .unavailable }

        let currentVersion = response.currentPolicyVersion
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let policyVersion = response.policy.version
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard response.policy.policyType == .aiScheduleParsing,
              !currentVersion.isEmpty,
              currentVersion == response.currentPolicyVersion,
              currentVersion == policyVersion,
              policyVersion == response.policy.version,
              !response.policy.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else { return .unavailable }

        return response.previouslyConsentedToCurrentPolicy
            ? .grant(policyVersion: currentVersion)
            : .showAgreement
    }
}

nonisolated enum AIScheduleConsentActivationPolicy {
    static func canSubmit(
        hasConfirmedTerms: Bool,
        hasPolicy: Bool,
        policyVersion: String?,
        isUpdating: Bool
    ) -> Bool {
        hasConfirmedTerms
            && hasPolicy
            && policyVersion?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            && !isUpdating
    }
}

private struct AIScheduleConsentActivationModal: View {
    @ObservedObject var store: AIScheduleParsingConsentStore
    let memberID: Int64
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var hasConfirmedTerms = false

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            SettingsModalHeader(
                titleKey: "settings.aiConsent.confirmTitle",
                closeDisabled: store.isUpdating,
                close: dismiss
            )
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                SettingsLocalization.text("settings.aiConsent.dataFlow")
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(DPSpacing.medium)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DPColor.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))

                if let policy = store.response?.policy {
                    DPLongFormDocument(content: policy.content)

                    Divider()

                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        Text(verbatim: "\(SettingsLocalization.string("settings.aiConsent.policyVersion")) \(policy.version)")
                        Text(verbatim: "\(SettingsLocalization.string("settings.aiConsent.effectiveDate")) \(policy.effectiveDate.rawValue)")
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                } else {
                    Label(
                        SettingsLocalization.string("settings.aiConsent.loadFailed"),
                        systemImage: "exclamationmark.triangle"
                    )
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
                }

                Toggle(isOn: $hasConfirmedTerms) {
                    SettingsLocalization.text("settings.aiConsent.confirmAcknowledgement")
                        .font(DPTypography.bodyMedium)
                        .foregroundStyle(DPColor.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .tint(DPColor.accent)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .disabled(store.isUpdating || store.response?.policy == nil)
                .onChange(of: hasConfirmedTerms) { _, _ in
                    guard !store.isUpdating, store.response?.policy != nil else { return }
                    DPHapticCenter.shared.emit(.selection)
                }
                .accessibilityLabel(SettingsLocalization.string("settings.aiConsent.confirmAcknowledgement"))
                .accessibilityValue(SettingsLocalization.string(
                    hasConfirmedTerms ? "settings.accessibility.on" : "settings.accessibility.off"
                ))
                .accessibilityHint(SettingsLocalization.string("settings.aiConsent.confirmAcknowledgementHint"))
                .accessibilityIdentifier("settings.aiConsent.confirmAcknowledgement")

                if let errorKey = store.errorKey {
                    Label(SettingsLocalization.string(errorKey), systemImage: "exclamationmark.circle.fill")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.danger)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityElement(children: .combine)
                        .accessibilityIdentifier("settings.aiConsent.error")
                }
            }
            .padding(DPSpacing.large)
        } footer: {
            SettingsModalActions {
                Button(action: dismiss) {
                    SettingsLocalization.text("settings.action.cancel")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(store.isUpdating)

                Button(action: enable) {
                    Group {
                        if store.isUpdating {
                            ProgressView()
                                .accessibilityLabel(SettingsLocalization.string("settings.aiConsent.updating"))
                        } else {
                            SettingsLocalization.text("settings.aiConsent.confirmEnable")
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(!canSubmit)
                .accessibilityHint(SettingsLocalization.string("settings.aiConsent.confirmEnableHint"))
                .accessibilityIdentifier("settings.aiConsent.confirmEnable")
            }
        }
    }

    private var canSubmit: Bool {
        AIScheduleConsentActivationPolicy.canSubmit(
            hasConfirmedTerms: hasConfirmedTerms,
            hasPolicy: store.response?.policy != nil,
            policyVersion: store.response?.currentPolicyVersion,
            isUpdating: store.isUpdating
        )
    }

    private func enable() {
        guard canSubmit,
              let policyVersion = store.response?.currentPolicyVersion
        else { return }

        Task {
            if await store.grant(for: memberID, policyVersion: policyVersion) {
                dismiss()
            }
        }
    }
}

private struct AIScheduleConsentPolicyView: View {
    @ObservedObject var store: AIScheduleParsingConsentStore
    let memberID: Int64?

    var body: some View {
        Group {
            if let policy = displayedPolicy {
                ScrollView {
                    VStack(alignment: .leading, spacing: DPSpacing.medium) {
                        SettingsLocalization.text("settings.aiConsent.dataFlow")
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(DPSpacing.medium)
                            .background(DPColor.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))

                        DPLongFormDocument(content: policy.content)

                        Divider()
                        Text("\(policy.version) · \(policy.effectiveDate.rawValue)")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .padding(.horizontal, DPLongFormDocumentLayout.horizontalPadding)
                    .padding(.vertical, DPLongFormDocumentLayout.verticalPadding)
                }
            } else if store.isLoading {
                ProgressView(SettingsLocalization.string("settings.loading"))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ContentUnavailableView {
                    Label(
                        SettingsLocalization.string("settings.aiConsent.loadFailed"),
                        systemImage: "exclamationmark.triangle"
                    )
                } actions: {
                    if let memberID {
                        Button(SettingsLocalization.string("settings.action.retry")) {
                            Task { await store.load(for: memberID, force: true) }
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
            }
        }
        .navigationTitle(SettingsLocalization.string("settings.aiConsent.policy"))
        .navigationBarTitleDisplayMode(.inline)
    }

    private var displayedPolicy: PolicyDTO? {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-long-form-policies") {
            return SettingsLongFormPolicyFixture.ai
        }
#endif
        return store.response?.policy
    }
}

private struct DeepLinkedPolicyView: View {
    let type: PolicyType
    @ObservedObject var model: SettingsViewModel

    var body: some View {
        if model.loadedSections.contains(.policies) {
            PolicyView(titleKey: titleKey, policy: policy)
        } else if model.policyLoadFailed {
            ContentUnavailableView {
                Label(
                    SettingsLocalization.string("settings.policy.loadError"),
                    systemImage: "exclamationmark.triangle"
                )
            } actions: {
                Button(SettingsLocalization.string("settings.action.retry")) {
                    Task { await model.reloadPolicies() }
                }
                .buttonStyle(.borderedProminent)
            }
            .navigationTitle(SettingsLocalization.string(titleKey))
        } else {
            ProgressView(SettingsLocalization.string("settings.loading"))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTitle(SettingsLocalization.string(titleKey))
        }
    }

    private var titleKey: String {
        type == .terms ? "settings.policy.terms" : "settings.policy.privacy"
    }

    private var policy: PolicyDTO? {
        type == .terms ? model.policies?.terms : model.policies?.privacy
    }
}

private func optionLabel(_ option: Visibility) -> String {
    switch option {
    case .publicAccess: "settings.visibility.public"
    case .friends: "settings.visibility.friends"
    case .family: "settings.visibility.family"
    case .privateAccess: "settings.visibility.private"
    case .unknown: "settings.visibility.friends"
    }
}

private func optionDescription(_ option: Visibility) -> String {
    switch option {
    case .publicAccess: "settings.visibility.public.description"
    case .friends: "settings.visibility.friends.description"
    case .family: "settings.visibility.family.description"
    case .privateAccess: "settings.visibility.private.description"
    case .unknown: "settings.visibility.friends.description"
    }
}

private func optionColor(_ option: Visibility) -> Color {
    switch option {
    case .publicAccess: DPColor.success
    case .friends: DPColor.accent
    case .family: DPColor.warning
    case .privateAccess: DPColor.danger
    case .unknown: DPColor.accent
    }
}
