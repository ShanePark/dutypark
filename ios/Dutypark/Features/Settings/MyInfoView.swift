import PhotosUI
import SwiftUI
import UIKit

/// Account-owned settings: the member profile, the duty pattern, managers and managed
/// accounts, sessions, linked social logins and the account actions. Preferences that
/// are not tied to the account identity stay in `SettingsView`.
struct MyInfoView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var model = SettingsViewModel()
    // Account deletion unregisters the device, so the account screen keeps the push
    // manager even though the notification preferences live in `SettingsView`.
    @StateObject private var push = APNsRegistrationManager.shared
    @State private var oauthClient = MobileOAuthClient()
    @State private var appleSignInClient = AppleSignInClient()
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoToCrop: UIImage?
    @State private var cameraPhoto: UIImage?
    @State private var showPhotoLibrary = false
    @State private var showCamera = false
    @State private var showPattern = false
    @State private var showPassword = false
    @State private var showAuxiliary = false
    @State private var showAccountDeletion = false
    @State private var accountDeletionIsWorking = false
    @State private var confirmation: SettingsConfirmation?
    @State private var confirmationAction = SettingsDestructiveActionGate()
    @State private var isLinking: OAuthProvider?
    @State private var isUnlinking: OAuthProvider?
    @State private var socialManagementPresentation: SettingsSocialManagementPresentation?
    @State private var socialAction = SettingsDestructiveActionGate()
    @State private var oauthNoticeMessage: String?
    private let onProfilePhotoChanged: () -> Void
    private let settingsService = SettingsService()

    init(onProfilePhotoChanged: @escaping () -> Void = {}) {
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
                        Task { await model.load(.myInfo) }
                    }
                    .buttonStyle(.borderedProminent)
                }
            } else {
                ScrollView {
                    LazyVStack(spacing: DPSpacing.medium) {
                        profileSection
                        patternSection
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
                    }
                    .padding(.horizontal, DPSpacing.medium)
                    .padding(.top, DPSpacing.large)
                    .padding(.bottom, DPSpacing.extraLarge)
                }
                .background(DPColor.backgroundSecondary)
                .refreshable { await model.load(.myInfo) }
            }
        }
        .accessibilityIdentifier("screen.myInfo")
        .task { await model.load(.myInfo) }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .photosPicker(
            isPresented: $showPhotoLibrary,
            selection: $selectedPhoto,
            matching: .images
        )
        .fullScreenCover(isPresented: $showCamera, onDismiss: cameraDidDismiss) {
            ProfileCameraPicker { image in
                cameraPhoto = image
                showCamera = false
            }
            .ignoresSafeArea()
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
                canDismiss: !confirmationIsWorking,
                dismissHaptic: nil
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
        .disabled(model.isWorking || confirmationAction.isWorking)
    }

    private var profileSection: some View {
        let cameraForeground = DPColor.textOnDark
        let cameraBackground = DPColor.accent
        let cameraBorder = DPColor.backgroundCard
        let touchTarget = DPSize.minimumTouchTarget
        return SettingsCard(title: "settings.profile.title", icon: "person") {
            HStack(spacing: DPSpacing.medium) {
                Menu {
                    Button {
                        DPHapticCenter.shared.emit(.selection)
                        showCamera = true
                    } label: {
                        Label(
                            SettingsLocalization.string("settings.photo.take"),
                            systemImage: "camera"
                        )
                    }
                    .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
                    .accessibilityIdentifier("settings.photo.take")

                    Button {
                        DPHapticCenter.shared.emit(.selection)
                        showPhotoLibrary = true
                    } label: {
                        Label(
                            SettingsLocalization.string("settings.photo.library"),
                            systemImage: "photo.on.rectangle"
                        )
                    }
                    .accessibilityIdentifier("settings.photo.library")

                    if hasVisibleProfilePhoto {
                        Divider()
                        Button {
                            confirmation = .deleteProfilePhoto
                        } label: {
                            Label(
                                SettingsLocalization.string("settings.photo.delete"),
                                systemImage: "trash"
                            )
                        }
                        .accessibilityIdentifier("settings.photo.delete")
                    }
                } label: {
                    ZStack(alignment: .bottomTrailing) {
                        profilePhoto

                        Image(systemName: "camera.fill")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(cameraForeground)
                            .frame(width: 30, height: 30)
                            .background(cameraBackground, in: Circle())
                            .overlay(Circle().stroke(cameraBorder, lineWidth: 2))
                            .frame(width: touchTarget, height: touchTarget)
                            .offset(x: DPSpacing.small, y: DPSpacing.small)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SettingsLocalization.text("settings.photo.actions"))
                .accessibilityIdentifier("settings.photo.actions")

                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    memberInfoRow("person", "settings.profile.name", model.member?.name ?? "-")
                    memberInfoRow("building.2", "settings.profile.team", model.member?.team ?? "-")
                    if let email = model.member?.email {
                        memberInfoRow("envelope", "settings.profile.email", email)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
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
        DPProfileAvatar(
            memberID: model.member?.id,
            profilePhotoVersion: model.member?.profilePhotoVersion ?? 0,
            size: 80
        )
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
                    DPHapticCenter.shared.emit(.routine)
                    withoutPresentationAnimation { showPattern = true }
                }
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
                        DPIconActionButton(
                            systemImage: "trash",
                            label: SettingsLocalization.string("settings.manager.remove"),
                            tone: .danger
                        ) {
                            guard let id = manager.id else { return }
                            confirmation = .removeManager(id: id, name: manager.name)
                        }
                        .padding(.trailing, DPSpacing.extraSmall - DPIconActionMetrics.touchPadding)
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
                        do {
                            try await model.restoreImpersonation()
                            try await session.finishExternalLogin(emitsHaptic: false)
                            DPHapticCenter.shared.emit(.success)
                        } catch {
                            DPHapticCenter.shared.emit(.error)
                        }
                    }
                } label: {
                    Label(SettingsLocalization.string("settings.managed.restore"), systemImage: "arrow.uturn.backward")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
            }
            ForEach(model.managedMembers, id: \.id) { member in
                HStack(spacing: DPSpacing.compact) {
                    DPProfileAvatar(
                        memberID: member.id,
                        profilePhotoVersion: member.profilePhotoVersion,
                        size: 40
                    )
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
            Button {
                DPHapticCenter.shared.emit(.routine)
                withoutPresentationAnimation { showAuxiliary = true }
            } label: {
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
                Button {
                    DPHapticCenter.shared.emit(.routine)
                    withoutPresentationAnimation { showPassword = true }
                } label: {
                    Label(SettingsLocalization.string("settings.password.change"), systemImage: "lock.rotation")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentSoftButtonStyle())
            }
            Button {
                withoutPresentationAnimation { showAccountDeletion = true }
            } label: {
                Label(SettingsLocalization.string("settings.account.delete"), systemImage: "person.crop.circle.badge.xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DangerSoftButtonStyle())
            .accessibilityIdentifier("settings.account.delete")
            }
        }
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
            switch SettingsSocialRowAction.resolve(isConnected: connected) {
            case .manage:
                Label(SettingsLocalization.string("settings.social.connected"), systemImage: "checkmark.circle.fill")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.success)
                    .fixedSize()
                Button {
                    guard !socialAction.isWorking else { return }
                    withoutPresentationAnimation {
                        DPHapticCenter.shared.emit(.routine)
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
            case .connect:
                Button {
                    guard !socialAction.isWorking else { return }
                    Task { await link(provider) }
                } label: {
                    HStack(spacing: DPSpacing.extraSmall) {
                        if isLinking == provider {
                            ProgressView()
                                .tint(DPColor.accent)
                        } else {
                            Image(systemName: "link.badge.plus")
                        }
                        SettingsLocalization.text("settings.social.connect")
                    }
                    .fixedSize()
                }
                .buttonStyle(AccentSoftButtonStyle())
                .disabled(socialAction.isWorking)
                .accessibilityIdentifier("settings.social.connect.\(provider.rawValue.lowercased())")
            }
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
            DPHapticCenter.shared.emit(.error)
            return
        }
        photoToCrop = image
    }

    private func cameraDidDismiss() {
        guard let cameraPhoto else { return }
        self.cameraPhoto = nil
        photoToCrop = cameraPhoto
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
            DPHapticCenter.shared.emit(.success)
        } catch MobileOAuthError.cancelled {
            return
        } catch AppleSignInError.cancelled {
            return
        } catch {
            oauthNoticeMessage = error.localizedDescription
            model.noticeIsError = true
            DPHapticCenter.shared.emit(.error)
        }
    }

    private func unlink(_ provider: OAuthProvider) async {
        guard SettingsSocialUnlinkPolicy.canUnlink(
            connectedProviderCount: connectedSocialProviderCount
        ) else {
            model.noticeIsError = true
            model.noticeKey = "settings.social.unlinkLastAuthenticationMethod"
            DPHapticCenter.shared.emit(.warning)
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
            DPHapticCenter.shared.emit(.success)
        } catch {
            model.noticeIsError = true
            model.noticeKey = SettingsSocialUnlinkPolicy.noticeKey(for: error)
            DPHapticCenter.shared.emit(.error)
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
        if requestedAction.requiresWarning {
            DPHapticCenter.shared.emit(.warning)
        }
        Task {
            switch requestedAction {
            case .deleteProfilePhoto:
                if await model.deleteProfilePhoto() {
                    onProfilePhotoChanged()
                }
            case .removeManager(let id, _):
                await model.unassignManager(id)
            case .switchManagedAccount(let id, _):
                do {
                    try await session.impersonate(memberId: id)
                } catch {
                    DPHapticCenter.shared.emit(.error)
                    confirmationAction.finish()
                    return
                }
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

private struct ProfileCameraPicker: UIViewControllerRepresentable {
    let completion: (UIImage?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(completion: completion)
    }

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        let completion: (UIImage?) -> Void

        init(completion: @escaping (UIImage?) -> Void) {
            self.completion = completion
        }

        func imagePickerController(
            _ picker: UIImagePickerController,
            didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]
        ) {
            completion(info[.originalImage] as? UIImage)
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            completion(nil)
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
                value: SettingsSessionClientPresentation.nonempty(token.remoteAddr)
            )
            SettingsSessionMetadataRow(
                labelKey: "settings.sessions.deviceLabel",
                icon: client.deviceIcon,
                value: SettingsSessionClientPresentation.nonempty(token.userAgent?.device)
            )
            SettingsSessionMetadataRow(
                labelKey: client.clientLabelKey,
                icon: client.clientIcon,
                value: client.clientValue
            )
        }
        .padding(DPSpacing.medium)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
    }

    private var client: SettingsSessionClientPresentation {
        SettingsSessionClientPresentation(token: token)
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
                    dismiss()
                } label: {
                    SettingsLocalization.text("settings.action.close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                Button {
                    confirmation = .save
                } label: {
                    SettingsLocalization.text("settings.action.save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(selectedIDs.isEmpty || hasHiddenSelection || model.isWorking)
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
        DPModalPanel(maximumPanelHeight: maximumHeight, scrollTarget: focusedField) {
            SettingsModalHeader(
                titleKey: "settings.password.change",
                closeDisabled: model.isWorking,
                close: dismiss
            )
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button(action: dismiss) {
                    SettingsLocalization.text("settings.action.close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
                Button(action: changePassword) {
                    SettingsLocalization.text("settings.action.save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(validationKey != nil || model.isWorking)
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
        .id(field)
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

    private enum Field { case name }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight, scrollTarget: focused ? Field.name : nil) {
            SettingsModalHeader(
                titleKey: "settings.auxiliary.create",
                closeDisabled: model.isWorking,
                close: dismiss
            )
        } content: {
            bodyContent
        } footer: {
            SettingsModalActions {
                Button(action: dismiss) {
                    SettingsLocalization.text("settings.action.close")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(model.isWorking)
                Button(action: createAccount) {
                    SettingsLocalization.text("settings.action.create")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
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
                .id(Field.name)
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
