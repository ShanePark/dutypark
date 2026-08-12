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
    @AppStorage(SettingsPreference.themeKey) private var themeCode = AppTheme.light.rawValue
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var photoToCrop: UIImage?
    @State private var showPhotoActions = false
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
                Form {
                    profileSection
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
                    informationSection
                    logoutSection
                }
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
        Section(SettingsLocalization.string("settings.profile.title")) {
            HStack(spacing: 16) {
                Button {
                    guard model.member?.hasProfilePhoto == true else { return }
                    Task { await cropExistingPhoto() }
                } label: {
                    profilePhoto
                }
                .buttonStyle(.plain)
                .accessibilityLabel(SettingsLocalization.text("settings.crop.existing"))
                VStack(alignment: .leading, spacing: 5) {
                    Text(model.member?.name ?? "-")
                        .font(.headline)
                    if let email = model.member?.email {
                        Text(email).font(.subheadline).foregroundStyle(.secondary)
                    }
                    Label(model.member?.team ?? "-", systemImage: "person.3")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Label(SettingsLocalization.string("settings.photo.choose"), systemImage: "photo")
                    .frame(minHeight: 44)
            }
            if model.member?.hasProfilePhoto == true {
                Button(role: .destructive) { showPhotoActions = true } label: {
                    Label(SettingsLocalization.string("settings.photo.delete"), systemImage: "trash")
                        .frame(minHeight: 44)
                }
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
            .frame(width: 72, height: 72)
            .clipShape(Circle())
        } else {
            profilePlaceholder
                .frame(width: 72, height: 72)
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

    private var visibilitySection: some View {
        Section {
            Picker(SettingsLocalization.string("settings.visibility.label"), selection: visibilityBinding) {
                SettingsLocalization.text("settings.visibility.public").tag(Visibility.publicAccess)
                SettingsLocalization.text("settings.visibility.friends").tag(Visibility.friends)
                SettingsLocalization.text("settings.visibility.family").tag(Visibility.family)
                SettingsLocalization.text("settings.visibility.private").tag(Visibility.privateAccess)
            }
        } header: {
            SettingsLocalization.text("settings.visibility.title")
        } footer: {
            VStack(alignment: .leading, spacing: 8) {
                SettingsLocalization.text("settings.visibility.description")
                if model.loadedSections.contains(.friends) {
                    visibilityAudience(
                        title: "settings.visibility.friendsAudience",
                        emptyKey: "settings.visibility.emptyFriends",
                        people: model.friends
                    )
                    visibilityAudience(
                        title: "settings.visibility.familyAudience",
                        emptyKey: "settings.visibility.emptyFamily",
                        people: model.friends.filter(\.isFamily)
                    )
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section(SettingsLocalization.string("settings.appearance.title")) {
            Picker(SettingsLocalization.string("settings.language"), selection: languageBinding) {
                ForEach(AppLanguage.allCases) { language in
                    Text(language.nativeName).tag(language.rawValue)
                }
            }
            Picker(SettingsLocalization.string("settings.theme"), selection: $themeCode) {
                SettingsLocalization.text("settings.theme.light").tag(AppTheme.light.rawValue)
                SettingsLocalization.text("settings.theme.dark").tag(AppTheme.dark.rawValue)
            }
        }
    }

    private var pushSection: some View {
        Section {
            Toggle(SettingsLocalization.string("settings.push.toggle"), isOn: pushBinding)
                .frame(minHeight: 44)
            if push.authorizationStatus == .denied {
                SettingsLocalization.text("settings.push.denied")
                    .font(.footnote)
                    .foregroundStyle(DPColor.warning)
            } else if push.registrationState == .failed {
                SettingsLocalization.text("settings.push.failed")
                    .font(.footnote)
                    .foregroundStyle(DPColor.danger)
            }
        } header: {
            SettingsLocalization.text("settings.push.title")
        } footer: {
            SettingsLocalization.text("settings.push.description")
        }
    }

    private var managerSection: some View {
        Section {
            if !model.availableManagers.isEmpty {
                Menu {
                    ForEach(model.availableManagers, id: \.id) { member in
                        if let id = member.id {
                            Button(member.name) { Task { await model.assignManager(id) } }
                        }
                    }
                } label: {
                    Label(SettingsLocalization.string("settings.manager.add"), systemImage: "person.badge.plus")
                        .frame(minHeight: 44)
                }
            }
            if model.managers.isEmpty {
                SettingsLocalization.text("settings.manager.empty").foregroundStyle(.secondary)
            } else {
                ForEach(model.managers, id: \.id) { manager in
                    HStack {
                        Text(manager.name)
                        Spacer()
                        Button(role: .destructive) { managerToRemove = manager } label: {
                            Image(systemName: "trash")
                                .frame(width: 44, height: 44)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        } header: {
            SettingsLocalization.text("settings.manager.title")
        } footer: {
            SettingsLocalization.text("settings.manager.description")
        }
    }

    private var managedAccountSection: some View {
        Section {
            if case .authenticated(let loginMember) = session.state, loginMember.isImpersonating {
                Button {
                    Task {
                        try? await model.restoreImpersonation()
                        try? await session.finishExternalLogin()
                    }
                } label: {
                    Label(SettingsLocalization.string("settings.managed.restore"), systemImage: "arrow.uturn.backward")
                        .frame(minHeight: 44)
                }
            }
            ForEach(model.managedMembers, id: \.id) { member in
                Button { memberToImpersonate = member } label: {
                    HStack {
                        Text(member.name)
                        Spacer()
                        Image(systemName: "rectangle.portrait.and.arrow.right")
                    }
                    .frame(minHeight: 44)
                }
            }
            Button { showAuxiliary = true } label: {
                Label(SettingsLocalization.string("settings.auxiliary.create"), systemImage: "person.crop.circle.badge.plus")
                    .frame(minHeight: 44)
            }
        } header: {
            SettingsLocalization.text("settings.managed.title")
        } footer: {
            SettingsLocalization.text("settings.managed.description")
        }
    }

    private var sessionSection: some View {
        Section {
            ForEach(sortedSessions) { token in
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(sessionName(token)).font(.body.weight(.medium))
                        if token.isCurrentLogin == true {
                            SettingsLocalization.text("settings.sessions.current")
                                .font(.caption)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(DPColor.accentSoft, in: Capsule())
                        }
                        Spacer()
                        if token.isCurrentLogin != true {
                            Button(role: .destructive) { sessionToRevoke = token } label: {
                                Image(systemName: "rectangle.portrait.and.arrow.right")
                                    .frame(width: 44, height: 44)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    if let lastUsed = token.lastUsed {
                        Text(lastUsed).font(.caption).foregroundStyle(.secondary)
                    }
                    if let createdDate = token.createdDate {
                        HStack(spacing: 4) {
                            SettingsLocalization.text("settings.sessions.created")
                            Text(createdDate)
                        }
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    }
                    HStack(spacing: 4) {
                        SettingsLocalization.text("settings.sessions.expires")
                        Text(token.validUntil)
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    if let remoteAddr = token.remoteAddr {
                        Text(remoteAddr).font(.caption).foregroundStyle(.secondary)
                    }
                }
            }
            Button(role: .destructive) {
                Task { await model.revokeOtherSessions() }
            } label: {
                SettingsLocalization.text("settings.sessions.revokeOthers")
                    .frame(minHeight: 44)
            }
        } header: {
            SettingsLocalization.text("settings.sessions.title")
        }
    }

    private var socialSection: some View {
        Section(SettingsLocalization.string("settings.social.title")) {
            socialRow(.kakao, connected: model.member?.kakaoId != nil)
            socialRow(.naver, connected: model.member?.naverId != nil)
        }
    }

    private var accountSection: some View {
        Section(SettingsLocalization.string("settings.account.title")) {
            if model.member?.hasPassword == true {
                Button { showPassword = true } label: {
                    Label(SettingsLocalization.string("settings.password.change"), systemImage: "lock.rotation")
                        .frame(minHeight: 44)
                }
            }
            Button(role: .destructive) { showDeleteInfo = true } label: {
                Label(SettingsLocalization.string("settings.account.delete"), systemImage: "person.crop.circle.badge.xmark")
                    .frame(minHeight: 44)
            }
        }
    }

    private var informationSection: some View {
        Section(SettingsLocalization.string("settings.information.title")) {
            if model.loadedSections.contains(.policies) {
                NavigationLink(SettingsLocalization.string("settings.policy.terms")) {
                    PolicyView(titleKey: "settings.policy.terms", policy: model.policies?.terms)
                }
                NavigationLink(SettingsLocalization.string("settings.policy.privacy")) {
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
            NavigationLink {
                GuideWebView(destination: .guide)
            } label: {
                Label(SettingsLocalization.string("settings.guide"), systemImage: "book")
                    .frame(minHeight: 44)
            }
            NavigationLink {
                GuideWebView(destination: .releaseNotes)
            } label: {
                Label(SettingsLocalization.string("settings.releaseNotes"), systemImage: "clock.arrow.circlepath")
                    .frame(minHeight: 44)
            }
        }
    }

    private var logoutSection: some View {
        Section {
            Button(role: .destructive) { showLogout = true } label: {
                Label(SettingsLocalization.string("settings.logout"), systemImage: "rectangle.portrait.and.arrow.right")
                    .frame(maxWidth: .infinity, minHeight: 44)
            }
            .accessibilityIdentifier("settings.logout")
        }
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

    private func socialRow(_ provider: OAuthProvider, connected: Bool) -> some View {
        HStack {
            Text(provider == .kakao ? "Kakao" : "Naver")
            Spacer()
            if connected {
                Label(SettingsLocalization.string("settings.social.connected"), systemImage: "checkmark.circle.fill")
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
            }
        }
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

private struct PasswordChangeView: View {
    let memberID: Int64
    @ObservedObject var model: SettingsViewModel
    let completion: () async -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var currentPassword = ""
    @State private var newPassword = ""
    @State private var confirmation = ""

    var body: some View {
        NavigationStack {
            Form {
                SecureField(SettingsLocalization.string("settings.password.current"), text: $currentPassword)
                    .textContentType(.password)
                SecureField(SettingsLocalization.string("settings.password.new"), text: $newPassword)
                    .textContentType(.newPassword)
                SecureField(SettingsLocalization.string("settings.password.confirm"), text: $confirmation)
                    .textContentType(.newPassword)
                if let validationKey {
                    SettingsLocalization.text(validationKey).foregroundStyle(DPColor.danger)
                }
            }
            .navigationTitle(SettingsLocalization.string("settings.password.change"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SettingsLocalization.string("settings.action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
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
                }
            }
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

    var body: some View {
        NavigationStack {
            Form {
                TextField(SettingsLocalization.string("settings.auxiliary.name"), text: $name)
                    .onChange(of: name) { _, value in
                        if value.count > 10 { name = String(value.prefix(10)) }
                    }
                SettingsLocalization.text("settings.auxiliary.description").font(.footnote).foregroundStyle(.secondary)
            }
            .navigationTitle(SettingsLocalization.string("settings.auxiliary.create"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(SettingsLocalization.string("settings.action.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(SettingsLocalization.string("settings.action.create")) {
                        Task {
                            await model.createAuxiliaryAccount(name: name.trimmingCharacters(in: .whitespacesAndNewlines))
                            if !model.noticeIsError { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || model.isWorking)
                }
            }
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
