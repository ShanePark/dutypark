import PhotosUI
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

struct SettingsView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = SettingsViewModel()
    @StateObject private var push = APNsRegistrationManager.shared
    @StateObject private var aiConsent = AIScheduleParsingConsentStore.shared
    @State private var oauthClient = MobileOAuthClient()
    @State private var appleSignInClient = AppleSignInClient()
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoToCrop: UIImage?
    @State private var showVisibility = false
    @State private var showPattern = false
    @State private var showPassword = false
    @State private var showAuxiliary = false
    @State private var showAIConsentConfirmation = false
    @State private var showAccountDeletion = false
    @State private var accountDeletionIsWorking = false
    @State private var confirmation: SettingsConfirmation?
    @State private var confirmationAction = SettingsDestructiveActionGate()
    @State private var isLinking: OAuthProvider?
    @State private var isUnlinking: OAuthProvider?
    @State private var socialManagementPresentation: SettingsSocialManagementPresentation?
    @State private var socialAction = SettingsDestructiveActionGate()
    @State private var oauthNoticeMessage: String?
    @Binding private var destination: SettingsDestination?
    private let onProfilePhotoChanged: () -> Void
    private let settingsService = SettingsService()

    init(
        destination: Binding<SettingsDestination?> = .constant(nil),
        onProfilePhotoChanged: @escaping () -> Void = {}
    ) {
        _destination = destination
        self.onProfilePhotoChanged = onProfilePhotoChanged
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
                        Task { await model.load() }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DPSpacing.medium) {
                    profileSection
                    patternSection
                    visibilitySection
                    appearanceSection
                    pushSection
                    aiConsentSection
                    if model.loadedSections.isSuperset(of: [.family, .managers]) {
                        managerSection
                    }
                    if model.loadedSections.contains(.managedAccounts) {
                        managedAccountSection
                    }
                    if model.loadedSections.contains(.sessions) {
                        sessionSection
                    }
                    socialSection
                    accountSection
                    logoutSection
                    informationSection
                    }
                    .padding(.horizontal, DPSpacing.medium)
                    .padding(.top, DPSpacing.large)
                    .padding(.bottom, DPSpacing.extraLarge)
                }
                .background(DPColor.backgroundSecondary)
                .refreshable { await model.load() }
            }
        }
        .accessibilityIdentifier("screen.settings")
        .task { await model.load() }
        .task { await push.resumeRegistration() }
        .task(id: model.member?.id) {
            guard let memberID = model.member?.id else { return }
            await aiConsent.load(for: memberID)
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .fullScreenCover(isPresented: $showPassword) {
            if let memberID = model.member?.id {
                DPModalOverlay(
                    onDismiss: { showPassword = false },
                    closeOnBackdrop: false,
                    canDismiss: !model.isWorking
                ) { availableSize, dismiss in
                    PasswordChangeView(
                        memberID: memberID,
                        model: model,
                        maximumHeight: availableSize.height,
                        dismiss: dismiss
                    ) {
                        showPassword = false
                        await session.logout()
                    }
                }
            }
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
        .fullScreenCover(isPresented: $showPattern) {
            DPModalOverlay(onDismiss: { showPattern = false }) { availableSize, dismiss in
                DutyPatternSettingsModal(
                    model: model,
                    maximumHeight: availableSize.height
                ) {
                    dismiss()
                }
            }
        }
        .fullScreenCover(isPresented: $showAuxiliary) {
            DPModalOverlay(
                onDismiss: { showAuxiliary = false },
                closeOnBackdrop: false,
                canDismiss: !model.isWorking
            ) { availableSize, dismiss in
                AuxiliaryAccountModal(
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
        .fullScreenCover(isPresented: $showAccountDeletion) {
            if let memberName = model.member?.name {
                DPModalOverlay(
                    onDismiss: { showAccountDeletion = false },
                    closeOnBackdrop: false,
                    canDismiss: !accountDeletionIsWorking
                ) { availableSize, dismiss in
                    AccountDeletionView(
                        push: push,
                        memberName: memberName,
                        maximumHeight: availableSize.height,
                        dismiss: dismiss,
                        workingChanged: { accountDeletionIsWorking = $0 }
                    )
                }
            }
        }
        .fullScreenCover(item: $socialManagementPresentation) { presentation in
            DPModalOverlay(
                onDismiss: { socialManagementPresentation = nil },
                canDismiss: !socialAction.isWorking
            ) { availableSize, dismiss in
                SocialConnectionManagementView(
                    state: socialManagementState(for: presentation.provider),
                    maximumHeight: availableSize.height,
                    dismiss: dismiss,
                    connect: { await link(presentation.provider) },
                    unlink: { await unlink(presentation.provider) }
                )
            }
        }
        .fullScreenCover(item: $confirmation) { requestedAction in
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { confirmation = nil },
                canDismiss: !confirmationIsWorking
            ) { availableSize, confirmationDismiss in
                DPConfirmationPanel(
                    title: SettingsLocalization.string(requestedAction.titleKey),
                    message: requestedAction.message,
                    confirmTitle: SettingsLocalization.string(requestedAction.confirmTitleKey),
                    cancelTitle: SettingsLocalization.string("settings.action.cancel"),
                    isDestructive: requestedAction.isDestructive,
                    isWorking: confirmationIsWorking,
                    maximumHeight: availableSize.height,
                    cancel: confirmationDismiss,
                    confirm: {
                        performConfirmation(requestedAction, dismiss: confirmationDismiss)
                    }
                )
            }
        }
        .sheet(isPresented: cropSheetBinding) {
            if let photoToCrop {
                ProfilePhotoCropView(image: photoToCrop) { jpeg in
                    self.photoToCrop = nil
                    Task {
                        if await model.uploadProfilePhoto(jpeg) {
                            onProfilePhotoChanged()
                        }
                    }
                } onCancel: {
                    self.photoToCrop = nil
                }
            }
        }
        .alert(SettingsLocalization.string("settings.notice.title"), isPresented: noticeBinding) {
            Button(SettingsLocalization.string("settings.action.confirm")) {
                model.noticeKey = nil
                oauthNoticeMessage = nil
            }
        } message: {
            if let oauthNoticeMessage {
                Text(verbatim: oauthNoticeMessage)
            } else if let key = model.noticeKey {
                SettingsLocalization.text(key)
            }
        }
        .alert(SettingsLocalization.string("settings.push.permissionTitle"), isPresented: $push.showsPermissionPreprompt) {
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
            Button(SettingsLocalization.string("settings.push.continue")) {
                Task { await push.continuePermissionRequest() }
            }
        } message: {
            SettingsLocalization.text("settings.push.permissionMessage")
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
        .disabled(model.isWorking || confirmationAction.isWorking)
        .navigationDestination(item: $destination) { destination in
            switch destination {
            case .guide:
                GuideWebView(destination: .guide)
            case .terms:
                DeepLinkedPolicyView(type: .terms, model: model)
            case .privacy:
                DeepLinkedPolicyView(type: .privacy, model: model)
            }
        }
    }

    private var profileSection: some View {
        let cameraForeground = DPColor.textOnDark
        let cameraBackground = DPColor.accent
        let cameraBorder = DPColor.backgroundCard
        let touchTarget = DPSize.minimumTouchTarget
        return SettingsCard(title: "settings.profile.title", icon: "person") {
            HStack(spacing: DPSpacing.medium) {
                ZStack(alignment: .bottomTrailing) {
                    Button {
                        guard hasVisibleProfilePhoto else { return }
                        Task { await cropExistingPhoto() }
                    } label: { profilePhoto }
                    .buttonStyle(.plain)
                    .accessibilityLabel(SettingsLocalization.text("settings.crop.existing"))

                    PhotosPicker(selection: $selectedPhoto, matching: .images) {
                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(cameraForeground)
                            .frame(width: 30, height: 30)
                            .background(cameraBackground, in: Circle())
                            .overlay(Circle().stroke(cameraBorder, lineWidth: 2))
                            .frame(width: touchTarget, height: touchTarget)
                    }
                    .accessibilityLabel(SettingsLocalization.text("settings.photo.choose"))
                }

                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    memberInfoRow("person", "settings.profile.name", model.member?.name ?? "-")
                    memberInfoRow("building.2", "settings.profile.team", model.member?.team ?? "-")
                    if let email = model.member?.email {
                        memberInfoRow("envelope", "settings.profile.email", email)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            if hasVisibleProfilePhoto {
                Button { confirmation = .deleteProfilePhoto } label: {
                    Label(SettingsLocalization.string("settings.photo.delete"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DangerSoftButtonStyle())
                .accessibilityIdentifier("settings.photo.delete")
            }
        }
    }

    private var hasVisibleProfilePhoto: Bool {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-ui-testing-profile-photo") {
            return true
        }
#endif
        return model.member?.hasProfilePhoto == true
    }

    @ViewBuilder
    private var profilePhoto: some View {
        if let url = model.profilePhotoURL() {
            AsyncImage(url: url) { phase in
                if case .success(let image) = phase {
                    image.resizable().scaledToFill()
                } else {
                    profilePlaceholder
                }
            }
            .frame(width: 80, height: 80)
            .clipShape(Circle())
        } else {
            profilePlaceholder
                .frame(width: 80, height: 80)
        }
    }

    private var profilePlaceholder: some View {
        Circle()
            .fill(.secondary.opacity(0.15))
            .overlay {
                Text(String(model.member?.name.first ?? "?"))
                    .font(.title2.bold())
                    .foregroundStyle(.secondary)
            }
    }

    private var patternSection: some View {
        SettingsCard(title: "settings.pattern.title", icon: "calendar.badge.clock") {
            if model.dutyPatternLoadFailed {
                HStack {
                    SettingsLocalization.text("settings.pattern.loadFailed")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                    Spacer()
                    Button(SettingsLocalization.string("settings.action.retry")) {
                        Task { await model.reloadDutyPattern() }
                    }
                    .buttonStyle(DPSecondaryButtonStyle())
                }
            } else if !model.loadedSections.contains(.dutyPattern) {
                HStack {
                    Spacer()
                    ProgressView().tint(DPColor.accent)
                    Spacer()
                }
                .frame(minHeight: 72)
            } else if let pattern = model.dutyPattern {
                DutyPatternSummary(pattern: pattern) {
                    withoutPresentationAnimation { showPattern = true }
                }
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
            Button { withoutPresentationAnimation { showVisibility = true } } label: {
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
            set: { themeCode = $0.rawValue }
        )
    }

    private var pushSection: some View {
        SettingsCard(title: "settings.push.title", icon: "bell") {
            Button { pushBinding.wrappedValue.toggle() } label: {
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
                    SettingsSwitch(isOn: push.isEnabled)
                }
                .padding(.horizontal, DPSpacing.compact)
                .frame(minHeight: 64)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(push.authorizationStatus == .denied)
            .accessibilityValue(SettingsLocalization.string(push.isEnabled ? "settings.accessibility.on" : "settings.accessibility.off"))
            .accessibilityAddTraits(.isButton)
            if push.authorizationStatus == .denied {
                Label(SettingsLocalization.string("settings.push.denied"), systemImage: "info.circle")
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

    private var managerSection: some View {
        SettingsCard(title: "settings.manager.title", icon: "shield") {
            Label(SettingsLocalization.string("settings.manager.description"), systemImage: "info.circle")
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
            if !model.availableManagers.isEmpty {
                Menu {
                    ForEach(model.availableManagers, id: \.id) { member in
                        if let id = member.id {
                            Button(member.name) { Task { await model.assignManager(id) } }
                        }
                    }
                } label: {
                    HStack {
                        SettingsLocalization.text("settings.manager.add")
                        Spacer()
                        Image(systemName: "chevron.up.chevron.down")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPOutlineButtonStyle())
            }
            if model.managers.isEmpty {
                SettingsLocalization.text("settings.manager.empty")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
            } else {
                ForEach(model.managers, id: \.id) { manager in
                    HStack {
                        Text(manager.name).font(DPTypography.body)
                        Spacer()
                        Button {
                            guard let id = manager.id else { return }
                            confirmation = .removeManager(id: id, name: manager.name)
                        } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(DPColor.textMuted)
                    }
                    .padding(.leading, DPSpacing.compact)
                    .background(DPColor.backgroundHover, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                }
            }

        }
    }

    private var managedAccountSection: some View {
        SettingsCard(title: "settings.managed.title", icon: "person.2") {
            if case .authenticated(let loginMember) = session.state, loginMember.isImpersonating {
                Button {
                    Task {
                        try? await model.restoreImpersonation()
                        try? await session.finishExternalLogin()
                    }
                } label: {
                    Label(SettingsLocalization.string("settings.managed.restore"), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
            }
            ForEach(model.managedMembers, id: \.id) { member in
                HStack(spacing: DPSpacing.compact) {
                    ProfileInitial(name: member.name)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(member.name).font(DPTypography.bodyMedium).foregroundStyle(DPColor.textPrimary)
                        if let team = member.team {
                            Text(team).font(DPTypography.caption).foregroundStyle(DPColor.textMuted)
                        }
                    }
                    Spacer()
                    Button {
                        guard let id = member.id else { return }
                        confirmation = .switchManagedAccount(id: id, name: member.name)
                    } label: {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .frame(width: 44, height: 44)
                            .background(DPColor.accentSoft, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.accent)
                }
                .padding(DPSpacing.compact)
                .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            Button { withoutPresentationAnimation { showAuxiliary = true } } label: {
                Label(SettingsLocalization.string("settings.auxiliary.create"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DashedSettingsButtonStyle())
        }
    }

    private var sessionSection: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            HStack(alignment: .center, spacing: DPSpacing.small) {
                Label(SettingsLocalization.string("settings.sessions.title"), systemImage: "iphone")
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                    .symbolRenderingMode(.monochrome)
                    .layoutPriority(1)
                Spacer(minLength: 0)
                if otherSessionCount > 0 {
                    Button {
                        withoutPresentationAnimation {
                            confirmation = .session(.otherSessions(count: otherSessionCount))
                        }
                    } label: {
                        Label(
                            SettingsLocalization.string("settings.sessions.revokeOthers"),
                            systemImage: "rectangle.portrait.and.arrow.right"
                        )
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    }
                    .buttonStyle(DangerSoftButtonStyle())
                    .disabled(model.isWorking)
                    .accessibilityIdentifier("settings.sessions.revokeOthers")
                }
            }

            if sortedSessions.isEmpty {
                SettingsLocalization.text("settings.sessions.empty")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 72)
            } else {
                ForEach(sortedSessions) { token in
                    SettingsSessionCard(token: token) {
                        withoutPresentationAnimation {
                            confirmation = .session(.session(token))
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .dpCard(padding: DPSpacing.large)
    }

    private var socialSection: some View {
        SettingsCard(title: "settings.social.title", icon: "link") {
            socialRow(
                .kakao,
                connected: model.member?.kakaoId != nil
            )
            socialRow(
                .naver,
                connected: model.member?.naverId != nil
            )
            socialRow(
                .apple,
                connected: model.member?.appleId != nil
            )
        }
    }

    private var accountSection: some View {
        SettingsCard(title: "settings.account.title", icon: "lock") {
            HStack(spacing: DPSpacing.compact) {
            if model.member?.hasPassword == true {
                Button { withoutPresentationAnimation { showPassword = true } } label: {
                    Label(SettingsLocalization.string("settings.password.change"), systemImage: "lock.rotation")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentSoftButtonStyle())
            }
            Button { withoutPresentationAnimation { showAccountDeletion = true } } label: {
                Label(SettingsLocalization.string("settings.account.delete"), systemImage: "person.crop.circle.badge.xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DangerSoftButtonStyle())
            .accessibilityIdentifier("settings.account.delete")
            }
        }
    }

    private var informationSection: some View {
        SettingsCard(title: "settings.information.title", icon: "info.circle") {
            HStack {
                SettingsLocalization.text("settings.language")
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Picker(SettingsLocalization.string("settings.language"), selection: languageBinding) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.nativeName).tag(language.rawValue)
                    }
                }
                .labelsHidden()
            }
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
                GuideWebView(destination: .guide)
            }
            settingsNavigationLink("settings.releaseNotes", icon: "clock.arrow.circlepath") {
                GuideWebView(destination: .releaseNotes)
            }
        }
    }

    private var logoutSection: some View {
        VStack {
            Button { confirmation = .logout } label: {
                Label(SettingsLocalization.string("settings.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(WarningSoftButtonStyle())
            .accessibilityIdentifier("settings.logout")
        }
        .dpCard(padding: DPSpacing.medium)
    }

    private var visibilityBinding: Binding<Visibility> {
        Binding(
            get: { model.member?.calendarVisibility ?? .friends },
            set: { value in Task { await model.updateVisibility(value) } }
        )
    }

    private var pushBinding: Binding<Bool> {
        Binding(
            get: { push.isEnabled },
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
            Task { _ = await aiConsent.revoke(for: memberID) }
            return
        }

        switch AIScheduleConsentSettingsActivationPolicy.decision(response: aiConsent.response) {
        case .showAgreement:
            aiConsent.dismissError()
            showAIConsentConfirmation = true
        case let .grant(policyVersion):
            aiConsent.dismissError()
            Task {
                _ = await aiConsent.grant(for: memberID, policyVersion: policyVersion)
            }
        case .unavailable:
            aiConsent.reportLoadFailure()
        }
    }

    private var languageBinding: Binding<String> {
        Binding(
            get: { AppLocalization.supportedLocale(languageCode: languageCode).identifier },
            set: { languageCode = $0 }
        )
    }

    private var sortedSessions: [SettingsRefreshToken] {
        SettingsSessionFormatter.sorted(model.sessions)
    }

    private var otherSessionCount: Int {
        model.sessions.filter(SettingsSessionPolicy.canRevoke).count
    }

    private var connectedSocialProviderCount: Int {
        [model.member?.kakaoId, model.member?.naverId, model.member?.appleId]
            .compactMap { $0 }
            .count
    }

    private var noticeBinding: Binding<Bool> {
        Binding(
            get: { model.noticeKey != nil || oauthNoticeMessage != nil },
            set: {
                if !$0 {
                    model.noticeKey = nil
                    oauthNoticeMessage = nil
                }
            }
        )
    }

    private var cropSheetBinding: Binding<Bool> {
        Binding(get: { photoToCrop != nil }, set: { if !$0 { photoToCrop = nil } })
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

    private func memberInfoRow(_ icon: String, _ labelKey: String, _ value: String) -> some View {
        HStack(spacing: DPSpacing.small) {
            Image(systemName: icon)
                .frame(width: DPSize.iconSmall)
                .foregroundStyle(DPColor.textSecondary)
            SettingsLocalization.text(labelKey)
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: 48, alignment: .leading)
            Text(value)
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .lineLimit(1)
        }
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
        }
        .buttonStyle(.plain)
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

    private func socialRow(
        _ provider: OAuthProvider,
        connected: Bool
    ) -> some View {
        HStack(spacing: DPSpacing.compact) {
            Group {
                if provider == .apple {
                    Image(systemName: "apple.logo")
                } else {
                    Text(provider == .kakao ? "K" : "N")
                }
            }
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(provider == .kakao ? DPColor.textOnLight : DPColor.textOnDark)
                .frame(width: 32, height: 32)
                .background(socialProviderColor(provider))
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
                .accessibilityHidden(true)
            Text(SettingsSocialManagementPolicy.providerName(provider))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
            Spacer(minLength: DPSpacing.small)
            if connected {
                Label(SettingsLocalization.string("settings.social.connected"), systemImage: "checkmark.circle.fill")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.success)
                    .fixedSize()
            }
            Button {
                guard !socialAction.isWorking else { return }
                withoutPresentationAnimation {
                    socialManagementPresentation = .init(provider: provider)
                }
            } label: {
                Image(systemName: "gearshape")
                    .font(.system(size: 16, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            .buttonStyle(.plain)
            .foregroundStyle(DPColor.textSecondary)
            .disabled(socialAction.isWorking)
            .accessibilityLabel(SettingsSocialManagementPolicy.manageLabel(for: provider))
            .accessibilityHint(SettingsLocalization.string("settings.social.manageHint"))
            .accessibilityIdentifier("settings.social.manage.\(provider.rawValue.lowercased())")
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .frame(minHeight: DPSize.minimumTouchTarget)
    }

    private func upload(_ item: PhotosPickerItem) async {
        defer { selectedPhoto = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data)
        else {
            model.noticeKey = "settings.photo.invalid"
            model.noticeIsError = true
            return
        }
        photoToCrop = image
    }

    private func cropExistingPhoto() async {
        guard let data = await model.profilePhotoData(), let image = UIImage(data: data) else {
            model.noticeKey = "settings.photo.invalid"
            model.noticeIsError = true
            return
        }
        photoToCrop = image
    }

    private func link(_ provider: OAuthProvider) async {
        guard isLinking == nil, isUnlinking == nil, socialAction.start() else { return }
        isLinking = provider
        defer {
            isLinking = nil
            socialAction.finish()
        }
        do {
            if provider == .apple {
                try await appleSignInClient.link()
            } else {
                try await oauthClient.link(provider: provider)
            }
            await model.reloadMember()
            oauthNoticeMessage = nil
            model.showNotice("settings.social.linked")
        } catch MobileOAuthError.cancelled {
            return
        } catch AppleSignInError.cancelled {
            return
        } catch {
            oauthNoticeMessage = error.localizedDescription
            model.noticeIsError = true
        }
    }

    private func unlink(_ provider: OAuthProvider) async {
        guard SettingsSocialUnlinkPolicy.canUnlink(
            connectedProviderCount: connectedSocialProviderCount
        ) else {
            model.noticeIsError = true
            model.noticeKey = "settings.social.unlinkLastAuthenticationMethod"
            return
        }
        guard isLinking == nil, isUnlinking == nil, socialAction.start() else { return }
        isUnlinking = provider
        defer {
            isUnlinking = nil
            socialAction.finish()
        }

        do {
            try await settingsService.unlinkSocialAccount(provider)
            await model.reloadMember()
            model.showNotice("settings.social.unlinked")
        } catch {
            model.noticeIsError = true
            model.noticeKey = SettingsSocialUnlinkPolicy.noticeKey(for: error)
        }
    }

    private func socialManagementState(for provider: OAuthProvider) -> SettingsSocialManagementState {
        let connected: Bool
        switch provider {
        case .kakao: connected = model.member?.kakaoId != nil
        case .naver: connected = model.member?.naverId != nil
        case .apple: connected = model.member?.appleId != nil
        }
        return SettingsSocialManagementState(
            provider: provider,
            isConnected: connected,
            connectedProviderCount: connectedSocialProviderCount,
            linkingProvider: isLinking,
            unlinkingProvider: isUnlinking
        )
    }

    private func socialProviderColor(_ provider: OAuthProvider) -> Color {
        switch provider {
        case .kakao: Color(red: 1, green: 0.9, blue: 0)
        case .naver: Color(red: 0.01, green: 0.78, blue: 0.28)
        case .apple: DPColor.surfaceStrong
        }
    }

    private var confirmationIsWorking: Bool {
        confirmationAction.isWorking || model.isWorking
    }

    private func performConfirmation(
        _ requestedAction: SettingsConfirmation,
        dismiss: @escaping () -> Void
    ) {
        guard confirmationAction.start() else { return }
        Task {
            switch requestedAction {
            case .deleteProfilePhoto:
                if await model.deleteProfilePhoto() {
                    onProfilePhotoChanged()
                }
            case .logout:
                await session.logout()
            case .removeManager(let id, _):
                await model.unassignManager(id)
            case .switchManagedAccount(let id, _):
                try? await session.impersonate(memberId: id)
            case .session(.session(let token)):
                if SettingsSessionPolicy.canRevoke(token) {
                    _ = await model.revokeSession(id: token.id)
                }
            case .session(.otherSessions):
                _ = await model.revokeOtherSessions()
            }
            confirmationAction.finish()
            dismiss()
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

    static func managementDescription(for provider: OAuthProvider) -> String {
        switch provider {
        case .apple:
            SettingsLocalization.string("settings.social.unlinkAppleDescription")
        case .kakao, .naver:
            localOnlyMessage(for: provider)
        }
    }

    static func confirmationMessage(for provider: OAuthProvider) -> String {
        if provider == .apple {
            return SettingsLocalization.string("settings.social.unlinkAppleConfirmMessage")
        }
        return localOnlyMessage(for: provider)
    }

    private static func localOnlyMessage(for provider: OAuthProvider) -> String {
        SettingsLocalization.string("settings.social.unlinkConfirmMessage")
            .replacingOccurrences(of: "{provider}", with: providerName(provider))
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

    private static func providerName(_ provider: OAuthProvider) -> String {
        switch provider {
        case .kakao: "Kakao"
        case .naver: "Naver"
        case .apple: SettingsLocalization.string("settings.social.apple")
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
    case logout
    case removeManager(id: MemberID, name: String)
    case switchManagedAccount(id: MemberID, name: String)
    case session(SettingsSessionConfirmation)

    var id: String {
        switch self {
        case .deleteProfilePhoto: "delete-profile-photo"
        case .logout: "logout"
        case .removeManager(let id, _): "remove-manager-\(id)"
        case .switchManagedAccount(let id, _): "switch-managed-account-\(id)"
        case .session(let confirmation): confirmation.id
        }
    }

    var titleKey: String {
        switch self {
        case .deleteProfilePhoto: "settings.photo.delete"
        case .logout: "settings.logout.confirmTitle"
        case .removeManager: "settings.manager.removeTitle"
        case .switchManagedAccount: "settings.managed.switch"
        case .session(let confirmation): confirmation.titleKey
        }
    }

    var confirmTitleKey: String {
        switch self {
        case .deleteProfilePhoto: "settings.photo.delete"
        case .logout: "settings.logout"
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
        case .logout:
            SettingsLocalization.string("settings.logout.confirmMessage")
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
        case .deleteProfilePhoto, .logout, .removeManager, .session: true
        }
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
                .replacingOccurrences(of: "{browser}", with: token.userAgent?.browser ?? "-")
                .replacingOccurrences(of: "{ip}", with: token.remoteAddr ?? "-")
        case .otherSessions(let count):
            SettingsLocalization.string("settings.sessions.revokeOthersMessage")
                .replacingOccurrences(of: "{count}", with: "\(count)")
        }
    }
}

private struct SettingsSessionCard: View {
    let token: SettingsRefreshToken
    let requestRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.compact) {
            HStack(alignment: .center, spacing: DPSpacing.small) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SettingsSessionFormatter.relativeTime(token.lastUsed))
                        .font(DPTypography.bodyMedium)
                        .foregroundStyle(DPColor.textPrimary)
                    Text(
                        "\(SettingsLocalization.string("settings.sessions.created")): "
                            + SettingsSessionFormatter.dateText(token.createdDate)
                    )
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                }
                Spacer(minLength: DPSpacing.small)
                if !SettingsSessionPolicy.canRevoke(token) {
                    SettingsLocalization.text("settings.sessions.current")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.success)
                        .padding(.horizontal, DPSpacing.small)
                        .padding(.vertical, DPSpacing.extraSmall)
                        .background(DPColor.successSoft, in: Capsule())
                        .fixedSize()
                } else {
                    Button(action: requestRevoke) {
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                            .font(.system(size: 16, weight: .medium))
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                            .background(DPColor.dangerSoft, in: Circle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.danger)
                    .accessibilityLabel(SettingsLocalization.string("settings.sessions.revoke"))
                    .accessibilityIdentifier("settings.sessions.revoke.\(token.id)")
                }
            }

            SettingsSessionMetadataRow(
                labelKey: "settings.sessions.ipLabel",
                icon: "globe",
                value: nonempty(token.remoteAddr)
            )
            SettingsSessionMetadataRow(
                labelKey: "settings.sessions.deviceLabel",
                icon: deviceIcon,
                value: nonempty(token.userAgent?.device)
            )
            SettingsSessionMetadataRow(
                labelKey: "settings.sessions.browserLabel",
                icon: "globe",
                value: nonempty(token.userAgent?.browser)
            )
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
    }

    private var deviceIcon: String {
        let device = token.userAgent?.device.lowercased() ?? ""
        let desktopTerms = ["other", "desktop", "mac", "windows", "linux"]
        return desktopTerms.contains(where: device.contains) ? "desktopcomputer" : "iphone"
    }

    private func nonempty(_ value: String?) -> String {
        guard let value, !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "-"
        }
        return value
    }
}

private struct SettingsSessionMetadataRow: View {
    let labelKey: String
    let icon: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
            SettingsLocalization.text(labelKey)
                .foregroundStyle(DPColor.textMuted)
                .frame(width: 76, alignment: .leading)
            HStack(spacing: DPSpacing.extraSmall) {
                Image(systemName: icon)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.iconSmall)
                Text(value)
                    .foregroundStyle(DPColor.textSecondary)
                    .lineLimit(2)
            }
        }
        .font(DPTypography.supporting)
    }
}

private struct SettingsCard<Content: View>: View {
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

private struct SettingsSwitch: View {
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

private struct ProfileInitial: View {
    let name: String

    var body: some View {
        Circle()
            .fill(DPColor.backgroundTertiary)
            .frame(width: 40, height: 40)
            .overlay {
                Text(String(name.first ?? "?"))
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textSecondary)
            }
    }
}

private struct AccentSoftButtonStyle: ButtonStyle {
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

private struct DangerSoftButtonStyle: ButtonStyle {
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

private struct WarningSoftButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DPTypography.bodyMedium)
            .foregroundStyle(DPColor.warning)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: 48)
            .background(configuration.isPressed ? DPColor.warningSoftHover : DPColor.warningSoft)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
    }
}

private struct DashedSettingsButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DPTypography.supporting)
            .foregroundStyle(DPColor.textMuted)
            .padding(.horizontal, DPSpacing.medium)
            .frame(minHeight: 48)
            .background(configuration.isPressed ? DPColor.backgroundHover : .clear)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(DPColor.borderPrimary, style: StrokeStyle(lineWidth: 2, dash: [6, 4]))
            }
    }
}

private struct SettingsModalHeader: View {
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
private struct SettingsModalActions<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        HStack(spacing: DPSpacing.small) { content }
            .padding(DPSpacing.compact)
    }
}

enum DutyPatternUnavailableCopy {
    static func key(reason: String?) -> String {
        switch reason?.uppercased() {
        case "TEAM_REQUIRED": "settings.pattern.unavailable.team"
        case "DUTY_TYPE_REQUIRED": "settings.pattern.unavailable.dutyType"
        default: "settings.pattern.unavailable.default"
        }
    }
}

private struct DutyPatternSummary: View {
    let pattern: DutyPatternDTO
    let open: () -> Void
    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        Button(action: open) {
            if let details = pattern.pattern {
                VStack(alignment: .leading, spacing: DPSpacing.compact) {
                    HStack(spacing: 5) {
                        ForEach(weekdays, id: \.rawValue) { weekday in
                            let duty = details.days.first { $0.weekday == weekday }?.dutyType
                            VStack(spacing: DPSpacing.extraSmall) {
                                Text(weekdayShort(weekday))
                                    .font(DPTypography.caption)
                                    .foregroundStyle(duty == nil ? DPColor.textMuted : DPColor.textPrimary)
                                Circle()
                                    .fill(duty.map { Color(settingsHex: $0.color) } ?? .clear)
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(DPColor.borderSecondary, style: duty == nil ? StrokeStyle(lineWidth: 1, dash: [2]) : StrokeStyle(lineWidth: 1)))
                                Text(duty?.name ?? CalendarLocalization.text("calendar.off"))
                                    .font(DPFont.light(size: 10, relativeTo: .caption2))
                                    .foregroundStyle(duty == nil ? DPColor.textMuted : DPColor.textSecondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.7)
                            }
                            .frame(maxWidth: .infinity, minHeight: 58)
                            .background(duty == nil ? .clear : DPColor.backgroundCard)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(duty == nil ? .clear : DPColor.borderPrimary))
                        }
                    }
                    HStack(spacing: DPSpacing.small) {
                        if details.holidayOff {
                            Text(CalendarLocalization.text("calendar.pattern.holidayOff"))
                                .font(DPTypography.caption)
                                .padding(.horizontal, DPSpacing.small)
                                .padding(.vertical, DPSpacing.extraSmall)
                                .background(DPColor.backgroundTertiary, in: Capsule())
                        }
                        Text("\(CalendarLocalization.text("calendar.pattern.effectiveFrom")) \(details.effectiveFrom.rawValue)")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                        Spacer()
                        SettingsLocalization.text("settings.pattern.edit")
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.accent)
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(DPColor.accent)
                    }
                    if hasHiddenDutyType(details) {
                        Label {
                            SettingsLocalization.text("settings.pattern.paused.title")
                        } icon: {
                            Image(systemName: "info.circle.fill")
                        }
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.warning)
                        .accessibilityIdentifier("settings.pattern.paused.summary")
                    }
                }
                .padding(DPSpacing.compact)
                .background(DPColor.backgroundSecondary)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                .overlay(RoundedRectangle(cornerRadius: DPRadius.large).stroke(DPColor.borderPrimary))
            } else if pattern.configurable {
                HStack(spacing: DPSpacing.compact) {
                    Image(systemName: "calendar.badge.plus")
                        .font(.system(size: 20))
                        .foregroundStyle(DPColor.accent)
                        .frame(width: 44, height: 44)
                        .background(DPColor.accentSoft, in: Circle())
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        SettingsLocalization.text("settings.pattern.create")
                            .font(DPTypography.bodyMedium)
                            .foregroundStyle(DPColor.textPrimary)
                        SettingsLocalization.text("settings.pattern.createDescription")
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                    }
                    Spacer()
                    Image(systemName: "chevron.right").foregroundStyle(DPColor.accent)
                }
                .padding(DPSpacing.medium)
                .overlay(RoundedRectangle(cornerRadius: DPRadius.large).stroke(DPColor.borderPrimary, style: StrokeStyle(lineWidth: 2, dash: [6, 4])))
            } else {
                SettingsLocalization.text(DutyPatternUnavailableCopy.key(reason: pattern.reason))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(!pattern.configurable)
    }

    private func hasHiddenDutyType(_ details: DutyPatternDetailsDTO) -> Bool {
        let visibleDutyTypeIDs = Set(pattern.dutyTypes.map(\.id))
        return details.days.contains { !visibleDutyTypeIDs.contains($0.dutyType.id) }
    }
}

private struct DutyPatternPausedWarning: View {
    var body: some View {
        HStack(alignment: .top, spacing: DPSpacing.small) {
            Image(systemName: "info.circle.fill")
                .font(.system(size: DPSize.iconSmall, weight: .semibold))
            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                SettingsLocalization.text("settings.pattern.paused.title")
                    .font(DPTypography.bodyMedium)
                SettingsLocalization.text("settings.pattern.paused.description")
                    .font(DPTypography.caption)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .foregroundStyle(DPColor.warning)
        .padding(DPSpacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DPColor.warningSoft, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.warningBorder)
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("settings.pattern.paused.warning")
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

struct DutyPatternSelectionState {
    private static let weekdays: [Weekday] = [
        .monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday,
    ]
    private var assignments: [Weekday: DutyTypeID]

    init(pattern: DutyPatternDetailsDTO?, dutyTypes: [DutyPatternDutyTypeDTO]) {
        if let pattern {
            assignments = Dictionary(
                uniqueKeysWithValues: pattern.days.map { ($0.weekday, $0.dutyType.id) }
            )
        } else if let defaultDutyTypeID = dutyTypes.first?.id {
            assignments = Dictionary(
                uniqueKeysWithValues: Self.weekdays.prefix(5).map { ($0, defaultDutyTypeID) }
            )
        } else {
            assignments = [:]
        }
    }

    var selectedWeekdays: [Weekday] {
        Self.weekdays.filter { assignments[$0] != nil }
    }

    func isSelected(_ weekday: Weekday) -> Bool {
        assignments[weekday] != nil
    }

    func dutyTypeID(for weekday: Weekday) -> DutyTypeID? {
        assignments[weekday]
    }

    mutating func toggle(_ weekday: Weekday, defaultDutyTypeID: DutyTypeID?) {
        if assignments.removeValue(forKey: weekday) != nil { return }
        guard let defaultDutyTypeID else { return }
        assignments[weekday] = defaultDutyTypeID
    }

    mutating func select(_ dutyTypeID: DutyTypeID, for weekday: Weekday) {
        guard assignments[weekday] != nil else { return }
        assignments[weekday] = dutyTypeID
    }

    func dutyType(
        for weekday: Weekday,
        visibleDutyTypes: [DutyPatternDutyTypeDTO],
        pattern: DutyPatternDetailsDTO?
    ) -> DutyPatternDutyTypeDTO? {
        guard let id = dutyTypeID(for: weekday) else { return nil }
        return visibleDutyTypes.first(where: { $0.id == id })
            ?? pattern?.days.first(where: { $0.weekday == weekday && $0.dutyType.id == id })?.dutyType
    }

    func hasHiddenSelection(visibleDutyTypes: [DutyPatternDutyTypeDTO]) -> Bool {
        selectedWeekdays.contains { isHiddenSelection($0, visibleDutyTypes: visibleDutyTypes) }
    }

    func isHiddenSelection(
        _ weekday: Weekday,
        visibleDutyTypes: [DutyPatternDutyTypeDTO]
    ) -> Bool {
        guard let selectedID = dutyTypeID(for: weekday) else { return false }
        return !visibleDutyTypes.contains { $0.id == selectedID }
    }
}

enum DutyPatternConfirmation: String, Identifiable {
    case save
    case delete

    var id: String { rawValue }
    var titleKey: String {
        switch self {
        case .save: "settings.pattern.saveConfirmTitle"
        case .delete: "settings.pattern.deleteConfirmTitle"
        }
    }
    var messageKey: String {
        switch self {
        case .save: "settings.pattern.saveConfirm"
        case .delete: "settings.pattern.deleteConfirm"
        }
    }
    var isDestructive: Bool { self == .delete }
}

private struct DutyPatternSettingsModal: View {
    @ObservedObject var model: SettingsViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var selectionState = DutyPatternSelectionState(pattern: nil, dutyTypes: [])
    @State private var holidayOff = true
    @State private var confirmation: DutyPatternConfirmation?
    @State private var expandedWeekday: Weekday?
    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
    private let weekdayColumns = Array(repeating: GridItem(.flexible(), spacing: DPSpacing.small), count: 4)

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            SettingsModalHeader(titleKey: "settings.pattern.title") { dismiss() }
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button {
                    confirmation = .save
                } label: {
                    SettingsLocalization.text("settings.action.save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(selectedIDs.isEmpty || hasHiddenSelection || model.isWorking)
                Button {
                    dismiss()
                } label: {
                    SettingsLocalization.text("settings.action.cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
            }
        }
        .onAppear {
            holidayOff = model.dutyPattern?.pattern?.holidayOff ?? true
            selectionState = DutyPatternSelectionState(
                pattern: model.dutyPattern?.pattern,
                dutyTypes: model.dutyPattern?.dutyTypes ?? []
            )
        }
        .fullScreenCover(item: $confirmation) { requestedAction in
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { confirmation = nil },
                canDismiss: !model.isWorking
            ) { availableSize, confirmationDismiss in
                DPConfirmationPanel(
                    title: SettingsLocalization.string(requestedAction.titleKey),
                    message: SettingsLocalization.string(requestedAction.messageKey),
                    confirmTitle: requestedAction == .save
                        ? SettingsLocalization.string("settings.action.save")
                        : CalendarLocalization.text("calendar.pattern.delete"),
                    cancelTitle: SettingsLocalization.string("settings.action.cancel"),
                    isDestructive: requestedAction.isDestructive,
                    isWorking: model.isWorking,
                    maximumHeight: availableSize.height,
                    cancel: confirmationDismiss,
                    confirm: {
                        perform(requestedAction, confirmationDismiss: confirmationDismiss)
                    }
                )
            }
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            if hasHiddenSelection {
                DutyPatternPausedWarning()
            }

            LazyVGrid(columns: weekdayColumns, spacing: DPSpacing.small) {
                ForEach(weekdays, id: \.rawValue) { weekday in
                    weekdayButton(weekday)
                }
            }

            VStack(spacing: DPSpacing.small) {
                ForEach(selectionState.selectedWeekdays, id: \.rawValue) { weekday in
                    dutyTypeRow(weekday)
                }
            }

            Button { holidayOff.toggle() } label: {
                HStack {
                    Text(CalendarLocalization.text("calendar.pattern.holidayOff"))
                        .font(DPTypography.body)
                        .foregroundStyle(DPColor.textPrimary)
                    Spacer()
                    SettingsSwitch(isOn: holidayOff)
                }
                .padding(.horizontal, DPSpacing.compact)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
            .accessibilityValue(SettingsLocalization.string(holidayOff ? "settings.accessibility.on" : "settings.accessibility.off"))
            .accessibilityAddTraits(.isButton)

            if let details = model.dutyPattern?.pattern {
                Text("\(CalendarLocalization.text("calendar.pattern.effectiveFrom")) \(details.effectiveFrom.rawValue)")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textMuted)
            }

            if model.dutyPattern?.pattern != nil {
                Button { confirmation = .delete } label: {
                    Label(CalendarLocalization.text("calendar.pattern.delete"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DangerSoftButtonStyle())
            }
        }
        .padding(DPSpacing.large)
    }

    private func weekdayButton(_ weekday: Weekday) -> some View {
        let selected = selectionState.isSelected(weekday)
        return Button {
            selectionState.toggle(
                weekday,
                defaultDutyTypeID: model.dutyPattern?.dutyTypes.first?.id
            )
        } label: {
            Text(weekdayLong(weekday))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(selected ? DPColor.textOnDark : DPColor.textSecondary)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                .background(
                    selected ? DPColor.accent : DPColor.backgroundSecondary,
                    in: RoundedRectangle(cornerRadius: DPRadius.standard)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(selected ? DPColor.accent : DPColor.borderPrimary)
                )
        }
        .buttonStyle(.plain)
        .disabled(model.isWorking)
        .accessibilityAddTraits(selected ? .isSelected : [])
    }

    private func dutyTypeRow(_ weekday: Weekday) -> some View {
        VStack(spacing: DPSpacing.extraSmall) {
            HStack(spacing: DPSpacing.compact) {
                Text(weekdayLong(weekday))
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textSecondary)
                    .frame(width: 44, alignment: .leading)

                Button {
                    withAnimation(.easeOut(duration: 0.15)) {
                        expandedWeekday = expandedWeekday == weekday ? nil : weekday
                    }
                } label: {
                    HStack(spacing: DPSpacing.compact) {
                        if let selected = selectedDutyType(for: weekday) {
                            Circle()
                                .fill(Color(settingsHex: selected.color))
                                .frame(width: 14, height: 14)
                                .overlay(Circle().stroke(DPColor.borderSecondary))
                            Text(selected.name)
                                .font(DPTypography.bodyMedium)
                                .foregroundStyle(DPColor.textPrimary)
                                .lineLimit(1)
                            if isHiddenSelection(weekday) {
                                hiddenBadge
                            }
                        }
                        Spacer(minLength: DPSpacing.small)
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(DPColor.textMuted)
                            .rotationEffect(.degrees(expandedWeekday == weekday ? 180 : 0))
                    }
                    .padding(.horizontal, DPSpacing.compact)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
                }
                .buttonStyle(.plain)
                .disabled(model.isWorking)
                .accessibilityLabel(dutyTypeAccessibilityLabel(for: weekday))
            }

            if expandedWeekday == weekday {
                VStack(spacing: 0) {
                    ForEach(dutyTypeOptions(for: weekday), id: \.id) { type in
                        let selected = selectionState.dutyTypeID(for: weekday) == type.id
                        Button {
                            selectionState.select(type.id, for: weekday)
                            withAnimation(.easeOut(duration: 0.15)) {
                                expandedWeekday = nil
                            }
                        } label: {
                            HStack(spacing: DPSpacing.compact) {
                                Circle()
                                    .fill(Color(settingsHex: type.color))
                                    .frame(width: DPSize.iconSmall, height: DPSize.iconSmall)
                                    .overlay(Circle().stroke(DPColor.borderSecondary))
                                Text(type.name)
                                    .font(DPTypography.bodyMedium)
                                    .foregroundStyle(selected ? DPColor.accent : DPColor.textPrimary)
                                    .lineLimit(1)
                                if !isVisibleDutyType(type) {
                                    hiddenBadge
                                }
                                Spacer()
                                if selected {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: DPSize.iconSmall, weight: .semibold))
                                        .foregroundStyle(DPColor.accent)
                                }
                            }
                            .padding(.horizontal, DPSpacing.compact)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(selected ? DPColor.accentSoft : DPColor.backgroundCard)
                        }
                        .buttonStyle(.plain)
                        .disabled(model.isWorking || !isVisibleDutyType(type))
                        .opacity(isVisibleDutyType(type) ? 1 : 0.55)
                        .accessibilityAddTraits(selected ? .isSelected : [])
                        .accessibilityLabel(
                            isVisibleDutyType(type)
                                ? type.name
                                : "\(type.name), \(SettingsLocalization.string("settings.pattern.hidden"))"
                        )
                    }
                }
                .padding(DPSpacing.small)
                .background(DPColor.backgroundCard, in: RoundedRectangle(cornerRadius: DPRadius.large))
                .overlay(RoundedRectangle(cornerRadius: DPRadius.large).stroke(DPColor.borderSecondary))
                .padding(.leading, 44 + DPSpacing.compact)
            }
        }
    }

    private var selectedIDs: [DutyTypeID] {
        selectionState.selectedWeekdays.compactMap { selectionState.dutyTypeID(for: $0) }
    }
    private var submittedDays: [DutyPatternDayUpdateDTO] {
        selectionState.selectedWeekdays.compactMap { weekday in
            guard let id = selectionState.dutyTypeID(for: weekday) else { return nil }
            return DutyPatternDayUpdateDTO(weekday: weekday, dutyTypeId: id)
        }
    }
    private var hasHiddenSelection: Bool {
        selectionState.hasHiddenSelection(
            visibleDutyTypes: model.dutyPattern?.dutyTypes ?? []
        )
    }

    private var hiddenBadge: some View {
        SettingsLocalization.text("settings.pattern.hidden")
            .font(DPTypography.caption)
            .foregroundStyle(DPColor.warning)
            .padding(.horizontal, DPSpacing.small)
            .padding(.vertical, 2)
            .background(DPColor.warningSoft, in: Capsule())
            .overlay(Capsule().stroke(DPColor.warningBorder))
    }

    private func isHiddenSelection(_ weekday: Weekday) -> Bool {
        selectionState.isHiddenSelection(
            weekday,
            visibleDutyTypes: model.dutyPattern?.dutyTypes ?? []
        )
    }

    private func dutyTypeAccessibilityLabel(for weekday: Weekday) -> String {
        let name = selectedDutyType(for: weekday)?.name ?? ""
        let hiddenSuffix = isHiddenSelection(weekday)
            ? ", \(SettingsLocalization.string("settings.pattern.hidden"))"
            : ""
        return "\(weekdayLong(weekday)): \(name)\(hiddenSuffix)"
    }

    private func selectedDutyType(for weekday: Weekday) -> DutyPatternDutyTypeDTO? {
        selectionState.dutyType(
            for: weekday,
            visibleDutyTypes: model.dutyPattern?.dutyTypes ?? [],
            pattern: model.dutyPattern?.pattern
        )
    }

    private func dutyTypeOptions(for weekday: Weekday) -> [DutyPatternDutyTypeDTO] {
        let visible = model.dutyPattern?.dutyTypes ?? []
        guard let selected = selectedDutyType(for: weekday),
              !visible.contains(where: { $0.id == selected.id })
        else { return visible }
        return [selected] + visible
    }

    private func isVisibleDutyType(_ dutyType: DutyPatternDutyTypeDTO) -> Bool {
        model.dutyPattern?.dutyTypes.contains(where: { $0.id == dutyType.id }) == true
    }

    private func perform(
        _ requestedAction: DutyPatternConfirmation,
        confirmationDismiss: @escaping () -> Void
    ) {
        Task {
            let succeeded = switch requestedAction {
            case .save:
                await model.saveDutyPattern(days: submittedDays, holidayOff: holidayOff)
            case .delete:
                await model.deleteDutyPattern()
            }
            guard succeeded else { return }
            confirmationDismiss()
            try? await Task.sleep(for: .milliseconds(180))
            dismiss()
        }
    }
}

private struct PasswordChangeView: View {
    let memberID: Int64
    @ObservedObject var model: SettingsViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let completion: () async -> Void
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: Field?

    private enum Field { case current, new, confirmation }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            SettingsModalHeader(
                titleKey: "settings.password.change",
                closeDisabled: model.isWorking,
                close: dismiss
            )
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button(action: changePassword) {
                    SettingsLocalization.text("settings.action.save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(validationKey != nil || model.isWorking)
                Button(action: dismiss) {
                    SettingsLocalization.text("settings.action.cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
            }
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            passwordField("settings.password.current", text: $currentPassword, field: .current, contentType: .password)
            passwordField("settings.password.new", text: $newPassword, field: .new, contentType: .newPassword)
            passwordField("settings.password.confirm", text: $confirmation, field: .confirmation, contentType: .newPassword)
            if let validationKey {
                SettingsLocalization.text(validationKey)
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
            }
        }
        .padding(DPSpacing.large)
    }

    private func changePassword() {
        Task {
            do {
                try await model.changePassword(
                    memberID: memberID,
                    currentPassword: currentPassword,
                    newPassword: newPassword
                )
                await completion()
            } catch {}
        }
    }

    private func passwordField(
        _ titleKey: String,
        text: Binding<String>,
        field: Field,
        contentType: UITextContentType
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            SettingsLocalization.text(titleKey)
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textPrimary)
            SecureField(SettingsLocalization.string(titleKey), text: text)
                .textContentType(contentType)
                .focused($focusedField, equals: field)
                .dpInputChrome(isFocused: focusedField == field)
        }
    }

    private var validationKey: String? {
        if currentPassword.isEmpty { return "settings.password.currentRequired" }
        if !(8...20).contains(newPassword.count) { return "settings.password.length" }
        if currentPassword == newPassword { return "settings.password.same" }
        if newPassword != confirmation { return "settings.password.mismatch" }
        return nil
    }
}

private struct AuxiliaryAccountModal: View {
    @ObservedObject var model: SettingsViewModel
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            SettingsModalHeader(
                titleKey: "settings.auxiliary.create",
                closeDisabled: model.isWorking,
                close: dismiss
            )
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button(action: createAccount) {
                    SettingsLocalization.text("settings.action.create")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
                Button(action: dismiss) {
                    SettingsLocalization.text("settings.action.cancel")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
            }
        }
    }

    private var bodyContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            SettingsLocalization.text("settings.auxiliary.description")
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
            SettingsLocalization.text("settings.auxiliary.name")
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textPrimary)
            TextField(SettingsLocalization.string("settings.auxiliary.name"), text: $name)
                .onChange(of: name) { _, value in
                    if value.count > 10 { name = String(value.prefix(10)) }
                }
                .focused($focused)
                .dpInputChrome(isFocused: focused)
                .onSubmit(createAccount)
            Text("\(name.count)/10")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(DPSpacing.large)
    }

    private func createAccount() {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty, !model.isWorking else { return }
        Task {
            await model.createAuxiliaryAccount(name: trimmedName)
            if !model.noticeIsError { dismiss() }
        }
    }
}

private struct PolicyView: View {
    let titleKey: String
    let policy: PolicyDTO?

    var body: some View {
        ScrollView {
            if let policy {
                VStack(alignment: .leading, spacing: 16) {
                    if let markdown = try? AttributedString(markdown: policy.content) {
                        Text(markdown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text(policy.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    Divider()
                    Text("\(policy.version) · \(policy.effectiveDate.rawValue)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding()
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
                    if let markdown = try? AttributedString(markdown: policy.content) {
                        Text(markdown)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    } else {
                        Text(policy.content)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }

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

                Button(action: dismiss) {
                    SettingsLocalization.text("settings.action.cancel")
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(store.isUpdating)
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
            if let policy = store.response?.policy {
                ScrollView {
                    VStack(alignment: .leading, spacing: DPSpacing.medium) {
                        SettingsLocalization.text("settings.aiConsent.dataFlow")
                            .font(DPTypography.body)
                            .foregroundStyle(DPColor.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(DPSpacing.medium)
                            .background(DPColor.accentSoft)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))

                        if let markdown = try? AttributedString(markdown: policy.content) {
                            Text(markdown)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        } else {
                            Text(policy.content)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }

                        Divider()
                        Text("\(policy.version) · \(policy.effectiveDate.rawValue)")
                            .font(DPTypography.caption)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    .padding(DPSpacing.medium)
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

private func weekdayShort(_ weekday: Weekday) -> String {
    switch weekday {
    case .monday: CalendarLocalization.text("calendar.weekday.mon")
    case .tuesday: CalendarLocalization.text("calendar.weekday.tue")
    case .wednesday: CalendarLocalization.text("calendar.weekday.wed")
    case .thursday: CalendarLocalization.text("calendar.weekday.thu")
    case .friday: CalendarLocalization.text("calendar.weekday.fri")
    case .saturday: CalendarLocalization.text("calendar.weekday.sat")
    case .sunday: CalendarLocalization.text("calendar.weekday.sun")
    case .unknown(let value): value
    }
}

private func weekdayLong(_ weekday: Weekday) -> String { weekdayShort(weekday) }

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

private extension Color {
    init(settingsHex value: String) {
        let cleaned = value.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var rgb: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&rgb)
        if cleaned.count == 6 {
            self.init(
                red: Double((rgb >> 16) & 0xFF) / 255,
                green: Double((rgb >> 8) & 0xFF) / 255,
                blue: Double(rgb & 0xFF) / 255
            )
        } else {
            self = DPColor.backgroundTertiary
        }
    }
}
