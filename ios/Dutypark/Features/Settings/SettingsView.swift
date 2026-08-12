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
    @State private var oauthClient = MobileOAuthClient()
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""
    @AppStorage(SettingsPreference.themeKey) private var themeCode = SettingsPreference.defaultTheme
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoToCrop: UIImage?
    @State private var showPhotoActions = false
    @State private var showVisibility = false
    @State private var showPattern = false
    @State private var showPassword = false
    @State private var showAuxiliary = false
    @State private var showLogout = false
    @State private var showDeleteInfo = false
    @State private var managerToRemove: MemberDTO?
    @State private var sessionToRevoke: SettingsRefreshToken?
    @State private var memberToImpersonate: MemberDTO?
    @State private var isLinking: OAuthProvider?
    @State private var oauthNoticeMessage: String?
    @Binding private var destination: SettingsDestination?
    private let onProfilePhotoChanged: () -> Void

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
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task { await upload(item) }
        }
        .sheet(isPresented: $showPassword) {
            if let memberID = model.member?.id {
                PasswordChangeView(memberID: memberID, model: model) {
                    showPassword = false
                    await push.unregister()
                    await session.logout()
                }
            }
        }
        .sheet(isPresented: $showVisibility) {
            VisibilitySettingsSheet(model: model)
        }
        .fullScreenCover(isPresented: $showPattern) {
            DPModalOverlay(onDismiss: { showPattern = false }) { _, dismiss in
                DutyPatternSettingsModal(model: model) {
                    dismiss()
                }
            }
        }
        .sheet(isPresented: $showAuxiliary) {
            AuxiliaryAccountView(model: model)
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
        .confirmationDialog(SettingsLocalization.string("settings.photo.actions"), isPresented: $showPhotoActions) {
            if model.member?.hasProfilePhoto == true {
                Button(SettingsLocalization.string("settings.photo.delete"), role: .destructive) {
                    Task {
                        if await model.deleteProfilePhoto() {
                            onProfilePhotoChanged()
                        }
                    }
                }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        }
        .confirmationDialog(SettingsLocalization.string("settings.logout.confirmTitle"), isPresented: $showLogout) {
            Button(SettingsLocalization.string("settings.logout"), role: .destructive) {
                Task {
                    await push.unregister()
                    await session.logout()
                }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        } message: {
            SettingsLocalization.text("settings.logout.confirmMessage")
        }
        .confirmationDialog(SettingsLocalization.string("settings.manager.removeTitle"), isPresented: removeManagerBinding) {
            Button(SettingsLocalization.string("settings.manager.remove"), role: .destructive) {
                guard let id = managerToRemove?.id else { return }
                Task { await model.unassignManager(id) }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        }
        .confirmationDialog(SettingsLocalization.string("settings.sessions.revokeTitle"), isPresented: revokeSessionBinding) {
            Button(SettingsLocalization.string("settings.sessions.revoke"), role: .destructive) {
                guard let id = sessionToRevoke?.id else { return }
                Task { await model.revokeSession(id: id) }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        }
        .confirmationDialog(SettingsLocalization.string("settings.managed.switchTitle"), isPresented: impersonateBinding) {
            Button(SettingsLocalization.string("settings.managed.switch")) {
                guard let id = memberToImpersonate?.id else { return }
                Task {
                    try? await session.impersonate(memberId: id)
                }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
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
        .alert(SettingsLocalization.string("settings.account.delete"), isPresented: $showDeleteInfo) {
            Button(SettingsLocalization.string("settings.action.confirm")) {}
        } message: {
            SettingsLocalization.text("settings.account.deleteInfo")
        }
        .alert(SettingsLocalization.string("settings.push.permissionTitle"), isPresented: $push.showsPermissionPreprompt) {
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
            Button(SettingsLocalization.string("settings.push.continue")) {
                Task { await push.continuePermissionRequest() }
            }
        } message: {
            SettingsLocalization.text("settings.push.permissionMessage")
        }
        .disabled(model.isWorking)
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
                        guard model.member?.hasProfilePhoto == true else { return }
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
            if model.member?.hasProfilePhoto == true {
                Button { showPhotoActions = true } label: {
                    Label(SettingsLocalization.string("settings.photo.delete"), systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DangerSoftButtonStyle())
            }
        }
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
            Button { showVisibility = true } label: {
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
                        Button { managerToRemove = manager } label: {
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
                    Button { memberToImpersonate = member } label: {
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
            Button { showAuxiliary = true } label: {
                Label(SettingsLocalization.string("settings.auxiliary.create"), systemImage: "plus")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DashedSettingsButtonStyle())
        }
    }

    private var sessionSection: some View {
        SettingsCard(title: "settings.sessions.title", icon: "iphone") {
            if sortedSessions.contains(where: { $0.isCurrentLogin != true }) {
                HStack {
                    Spacer()
                    Button { Task { await model.revokeOtherSessions() } } label: {
                        Label(SettingsLocalization.string("settings.sessions.revokeOthers"), systemImage: "rectangle.portrait.and.arrow.right")
                    }
                    .buttonStyle(DangerSoftButtonStyle())
                }
            }
            ForEach(sortedSessions) { token in
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(token.lastUsed ?? "-")
                                .font(DPTypography.bodyMedium)
                                .foregroundStyle(DPColor.textPrimary)
                            if let createdDate = token.createdDate {
                                Text("\(SettingsLocalization.string("settings.sessions.created")): \(createdDate)")
                                    .font(DPTypography.caption)
                                    .foregroundStyle(DPColor.textMuted)
                            }
                        }
                        if token.isCurrentLogin == true {
                            SettingsLocalization.text("settings.sessions.current")
                                .font(DPTypography.caption)
                                .foregroundStyle(DPColor.success)
                                .padding(.horizontal, DPSpacing.small)
                                .padding(.vertical, DPSpacing.extraSmall)
                                .background(DPColor.successSoft, in: Capsule())
                        }
                        Spacer()
                        if token.isCurrentLogin != true {
                            Button { sessionToRevoke = token } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .font(.system(size: 15))
                                    .frame(width: 32, height: 32)
                                    .background(DPColor.dangerSoft, in: Circle())
                                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(DPColor.danger)
                        }
                    }
                    Label(token.remoteAddr ?? "-", systemImage: "globe")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                    HStack(spacing: DPSpacing.small) {
                        Image(systemName: token.userAgent?.device == "Other" ? "desktopcomputer" : "iphone")
                        Text(sessionName(token))
                    }
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                }
                .padding(DPSpacing.compact)
                .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
            }
        }
    }

    private var socialSection: some View {
        SettingsCard(title: "settings.social.title", icon: "link") {
            socialRow(.kakao, connected: model.member?.kakaoId != nil)
            socialRow(.naver, connected: model.member?.naverId != nil)
        }
    }

    private var accountSection: some View {
        SettingsCard(title: "settings.account.title", icon: "lock") {
            HStack(spacing: DPSpacing.compact) {
            if model.member?.hasPassword == true {
                Button { showPassword = true } label: {
                    Label(SettingsLocalization.string("settings.password.change"), systemImage: "lock.rotation")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(AccentSoftButtonStyle())
            }
            Button { showDeleteInfo = true } label: {
                Label(SettingsLocalization.string("settings.account.delete"), systemImage: "person.crop.circle.badge.xmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DangerSoftButtonStyle())
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
            Button { showLogout = true } label: {
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

    private var languageBinding: Binding<String> {
        Binding(
            get: { languageCode.isEmpty ? detectedLanguage.rawValue : languageCode },
            set: { languageCode = $0 }
        )
    }

    private var detectedLanguage: AppLanguage {
        let value = Locale.preferredLanguages.first?.lowercased() ?? "ko"
        if value.hasPrefix("en") { return .english }
        if value.hasPrefix("ja") { return .japanese }
        if value.hasPrefix("zh") { return .chinese }
        if value.hasPrefix("es") { return .spanish }
        return .korean
    }

    private var sortedSessions: [SettingsRefreshToken] {
        model.sessions.sorted {
            if $0.isCurrentLogin == true { return true }
            if $1.isCurrentLogin == true { return false }
            return ($0.lastUsed ?? "") > ($1.lastUsed ?? "")
        }
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

    private var removeManagerBinding: Binding<Bool> {
        Binding(get: { managerToRemove != nil }, set: { if !$0 { managerToRemove = nil } })
    }

    private var revokeSessionBinding: Binding<Bool> {
        Binding(get: { sessionToRevoke != nil }, set: { if !$0 { sessionToRevoke = nil } })
    }

    private var impersonateBinding: Binding<Bool> {
        Binding(get: { memberToImpersonate != nil }, set: { if !$0 { memberToImpersonate = nil } })
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

    private func socialRow(_ provider: OAuthProvider, connected: Bool) -> some View {
        HStack(spacing: DPSpacing.compact) {
            Text(provider == .kakao ? "K" : "N")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(provider == .kakao ? DPColor.textOnLight : DPColor.textOnDark)
                .frame(width: 32, height: 32)
                .background(provider == .kakao ? Color(red: 1, green: 0.9, blue: 0) : Color(red: 0.01, green: 0.78, blue: 0.28))
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.small))
            Text(provider == .kakao ? "Kakao" : "Naver")
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
            Spacer()
            if connected {
                Label(SettingsLocalization.string("settings.social.connected"), systemImage: "checkmark.circle.fill")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.success)
            } else {
                Button {
                    Task { await link(provider) }
                } label: {
                    if isLinking == provider {
                        ProgressView()
                    } else {
                        SettingsLocalization.text("settings.social.connect")
                    }
                }
                .disabled(isLinking != nil)
                .buttonStyle(AccentSoftButtonStyle())
            }
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .frame(minHeight: 44)
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
        isLinking = provider
        defer { isLinking = nil }
        do {
            try await oauthClient.link(provider: provider)
            await model.reloadMember()
            model.noticeKey = "settings.social.linked"
        } catch MobileOAuthError.cancelled {
            return
        } catch {
            oauthNoticeMessage = error.localizedDescription
            model.noticeIsError = true
        }
    }

    private func sessionName(_ token: SettingsRefreshToken) -> String {
        guard let agent = token.userAgent else {
            return SettingsLocalization.string("settings.sessions.unknown")
        }
        let parts = [agent.device, agent.browser, agent.os].filter { !$0.isEmpty }
        return parts.isEmpty ? SettingsLocalization.string("settings.sessions.unknown") : parts.joined(separator: " · ")
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
    let close: () -> Void

    var body: some View {
        HStack {
            SettingsLocalization.text(titleKey)
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer()
            Button(action: close) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: 44, height: 44)
                    .background(DPColor.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, DPSpacing.large)
        .frame(minHeight: 64)
        .overlay(alignment: .bottom) { Divider().overlay(DPColor.borderPrimary) }
    }
}

private struct SettingsModalActions<Content: View>: View {
    @ViewBuilder let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }

    var body: some View {
        HStack(spacing: DPSpacing.compact) { content }
            .padding(DPSpacing.large)
            .background(DPColor.backgroundModal)
            .overlay(alignment: .top) { Divider().overlay(DPColor.borderPrimary) }
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
                Text(pattern.reason ?? CalendarLocalization.text("calendar.pattern.unavailable"))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
        .disabled(!pattern.configurable)
    }
}

private struct VisibilitySettingsSheet: View {
    @ObservedObject var model: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    private let options: [Visibility] = [.publicAccess, .friends, .family, .privateAccess]

    var body: some View {
        VStack(spacing: 0) {
            SettingsModalHeader(titleKey: "settings.visibility.modalTitle") { dismiss() }
            ScrollView {
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
            SettingsModalActions {
                Button(SettingsLocalization.string("settings.visibility.close")) { dismiss() }
                    .buttonStyle(DPSecondaryButtonStyle())
                    .frame(maxWidth: .infinity)
            }
        }
        .background(DPColor.backgroundModal)
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
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

private struct DutyPatternSettingsModal: View {
    @ObservedObject var model: SettingsViewModel
    let dismiss: () -> Void
    @State private var selections: [Weekday: DutyTypeID?] = [:]
    @State private var holidayOff = true
    @State private var confirmsSave = false
    @State private var confirmsDelete = false
    private let weekdays: [Weekday] = [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]

    var body: some View {
        VStack(spacing: 0) {
            SettingsModalHeader(titleKey: "settings.pattern.title") { dismiss() }
            ScrollView {
                VStack(alignment: .leading, spacing: DPSpacing.compact) {
                    if let details = model.dutyPattern?.pattern {
                        Text("\(CalendarLocalization.text("calendar.pattern.effectiveFrom")) \(details.effectiveFrom.rawValue)")
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textMuted)
                    }
                    ForEach(weekdays, id: \.rawValue) { weekday in
                        HStack {
                            Text(weekdayLong(weekday))
                                .font(DPTypography.bodyMedium)
                                .foregroundStyle(DPColor.textPrimary)
                            Spacer()
                            Menu(selectionName(weekday)) {
                                Button(CalendarLocalization.text("calendar.off")) { selections[weekday] = nil }
                                ForEach(model.dutyPattern?.dutyTypes ?? [], id: \.id) { type in
                                    Button(type.name) { selections[weekday] = type.id }
                                }
                            }
                            .foregroundStyle(DPColor.textPrimary)
                        }
                        .padding(.horizontal, DPSpacing.compact)
                        .frame(minHeight: 48)
                        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay(RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary))
                    }
                    Button { holidayOff.toggle() } label: {
                        HStack {
                            Text(CalendarLocalization.text("calendar.pattern.holidayOff"))
                                .font(DPTypography.body)
                                .foregroundStyle(DPColor.textPrimary)
                            Spacer()
                            SettingsSwitch(isOn: holidayOff)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .accessibilityValue(SettingsLocalization.string(holidayOff ? "settings.accessibility.on" : "settings.accessibility.off"))
                    .accessibilityAddTraits(.isButton)

                    if model.dutyPattern?.pattern != nil {
                        Button { confirmsDelete = true } label: {
                            Label(CalendarLocalization.text("calendar.pattern.delete"), systemImage: "trash")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(DangerSoftButtonStyle())
                    }
                }
                .padding(DPSpacing.large)
            }
            SettingsModalActions {
                Button(SettingsLocalization.string("settings.action.save")) {
                    confirmsSave = true
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(selectedIDs.isEmpty || hasHiddenSelection || model.isWorking)
                Button(SettingsLocalization.string("settings.action.cancel")) { dismiss() }
                    .buttonStyle(DPSecondaryButtonStyle())
            }
        }
        .background(DPColor.backgroundModal)
        .onAppear {
            holidayOff = model.dutyPattern?.pattern?.holidayOff ?? true
            selections = Dictionary(uniqueKeysWithValues: (model.dutyPattern?.pattern?.days ?? []).map { ($0.weekday, Optional($0.dutyType.id)) })
        }
        .confirmationDialog(SettingsLocalization.string("settings.pattern.saveConfirmTitle"), isPresented: $confirmsSave) {
            Button(SettingsLocalization.string("settings.action.save")) {
                Task {
                    if await model.saveDutyPattern(days: submittedDays, holidayOff: holidayOff) { dismiss() }
                }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        } message: {
            SettingsLocalization.text("settings.pattern.saveConfirm")
        }
        .confirmationDialog(SettingsLocalization.string("settings.pattern.deleteConfirmTitle"), isPresented: $confirmsDelete) {
            Button(CalendarLocalization.text("calendar.pattern.delete"), role: .destructive) {
                Task { if await model.deleteDutyPattern() { dismiss() } }
            }
            Button(SettingsLocalization.string("settings.action.cancel"), role: .cancel) {}
        } message: {
            SettingsLocalization.text("settings.pattern.deleteConfirm")
        }
    }

    private var selectedIDs: [DutyTypeID] { selections.values.compactMap { $0 } }
    private var submittedDays: [DutyPatternDayUpdateDTO] {
        weekdays.compactMap { weekday in
            guard let selected = selections[weekday], let id = selected else { return nil }
            return DutyPatternDayUpdateDTO(weekday: weekday, dutyTypeId: id)
        }
    }
    private var hasHiddenSelection: Bool {
        let visible = Set(model.dutyPattern?.dutyTypes.map(\.id) ?? [])
        return selectedIDs.contains { !visible.contains($0) }
    }
    private func selectionName(_ weekday: Weekday) -> String {
        guard let selected = selections[weekday], let id = selected else { return CalendarLocalization.text("calendar.off") }
        return model.dutyPattern?.dutyTypes.first(where: { $0.id == id })?.name
            ?? model.dutyPattern?.pattern?.days.first(where: { $0.weekday == weekday && $0.dutyType.id == id })?.dutyType.name
            ?? CalendarLocalization.text("calendar.off")
    }
}

private struct PasswordChangeView: View {
    let memberID: Int64
    @ObservedObject var model: SettingsViewModel
    let completion: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""
    @FocusState private var focusedField: Field?

    private enum Field { case current, new, confirmation }

    var body: some View {
        VStack(spacing: 0) {
            SettingsModalHeader(titleKey: "settings.password.change") { dismiss() }
            ScrollView {
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
            SettingsModalActions {
                Button(SettingsLocalization.string("settings.action.save")) {
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
                    .disabled(validationKey != nil || model.isWorking)
                    .buttonStyle(DPPrimaryButtonStyle())
                Button(SettingsLocalization.string("settings.action.cancel")) { dismiss() }
                    .buttonStyle(DPSecondaryButtonStyle())
            }
        }
        .background(DPColor.backgroundModal)
        .presentationDetents([.height(530)])
        .presentationDragIndicator(.hidden)
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

private struct AuxiliaryAccountView: View {
    @ObservedObject var model: SettingsViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @FocusState private var focused: Bool

    var body: some View {
        VStack(spacing: 0) {
            SettingsModalHeader(titleKey: "settings.auxiliary.create") { dismiss() }
            ScrollView {
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
                Text("\(name.count)/10")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(DPSpacing.large)
            }
            SettingsModalActions {
                Button(SettingsLocalization.string("settings.action.create")) {
                        Task {
                            await model.createAuxiliaryAccount(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                            if !model.noticeIsError { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
                    .buttonStyle(DPPrimaryButtonStyle())
                Button(SettingsLocalization.string("settings.action.cancel")) { dismiss() }
                    .buttonStyle(DPSecondaryButtonStyle())
            }
        }
        .background(DPColor.backgroundModal)
        .presentationDetents([.height(390)])
        .presentationDragIndicator(.hidden)
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
