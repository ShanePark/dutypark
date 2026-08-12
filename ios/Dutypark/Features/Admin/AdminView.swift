import SwiftUI

struct AdminRootView: View {
    @EnvironmentObject private var session: SessionStore
    let onOpenCalendar: (MemberID) -> Void

    var body: some View {
        Group {
            if isAdmin {
                List {
                    Section {
                        NavigationLink {
                            AdminMemberListView(onOpenCalendar: onOpenCalendar)
                        } label: {
                            AdminNavigationLabel(
                                title: AdminLocalization.string("admin.nav.members"),
                                subtitle: AdminLocalization.string("admin.nav.members.subtitle"),
                                systemImage: "person.3.fill",
                                color: DPColor.accent
                            )
                        }

                        NavigationLink {
                            AdminTeamListView()
                        } label: {
                            AdminNavigationLabel(
                                title: AdminLocalization.string("admin.nav.teams"),
                                subtitle: AdminLocalization.string("admin.nav.teams.subtitle"),
                                systemImage: "building.2.fill",
                                color: DPColor.success
                            )
                        }
                    } header: {
                        Text(AdminLocalization.string("admin.section.management"))
                    }

                    Section {
                        NavigationLink {
                            AdminAuthenticatedWebView(
                                path: "admin/dev",
                                title: AdminLocalization.string("admin.nav.development")
                            )
                        } label: {
                            AdminNavigationLabel(
                                title: AdminLocalization.string("admin.nav.development"),
                                subtitle: AdminLocalization.string("admin.nav.development.subtitle"),
                                systemImage: "hammer.fill",
                                color: DPColor.warning
                            )
                        }

                        NavigationLink {
                            AdminAuthenticatedWebView(
                                path: "docs/index.html",
                                title: AdminLocalization.string("admin.nav.apiDocumentation")
                            )
                        } label: {
                            AdminNavigationLabel(
                                title: AdminLocalization.string("admin.nav.apiDocumentation"),
                                subtitle: AdminLocalization.string("admin.nav.apiDocumentation.subtitle"),
                                systemImage: "doc.text.fill",
                                color: DPColor.textSecondary
                            )
                        }
                    } header: {
                        Text(AdminLocalization.string("admin.section.developer"))
                    }
                }
                .listStyle(.insetGrouped)
            } else {
                ContentUnavailableView(
                    AdminLocalization.string("admin.access.title"),
                    systemImage: "lock.shield",
                    description: Text(AdminLocalization.string("admin.access.message"))
                )
            }
        }
        .navigationTitle(AdminLocalization.string("admin.menu.title"))
        .navigationBarTitleDisplayMode(.large)
        .accessibilityIdentifier("screen.admin")
    }

    private var isAdmin: Bool {
        guard case .authenticated(let member) = session.state else { return false }
        return member.isAdmin
    }
}
private struct AdminNavigationLabel: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let color: Color

    var body: some View {
        HStack(spacing: DPSpacing.compact) {
            Image(systemName: systemImage)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.12), in: RoundedRectangle(cornerRadius: DPRadius.standard))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                Text(subtitle)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .frame(minHeight: DPSize.minimumTouchTarget)
    }
}

struct AdminMemberListView: View {
    @StateObject private var model: AdminMemberListViewModel
    @State private var searchText = ""
    let onOpenCalendar: (MemberID) -> Void

    init(
        model: @autoclosure @escaping () -> AdminMemberListViewModel = AdminMemberListViewModel(),
        onOpenCalendar: @escaping (MemberID) -> Void
    ) {
        _model = StateObject(wrappedValue: model())
        self.onOpenCalendar = onOpenCalendar
    }

    var body: some View {
        Group {
            if model.isLoading && model.members.isEmpty {
                ProgressView(AdminLocalization.string("admin.common.loading"))
            } else if model.loadFailed && model.members.isEmpty {
                ContentUnavailableView {
                    Label(AdminLocalization.string("admin.members.loadFailed"), systemImage: "wifi.exclamationmark")
                } actions: {
                    Button(AdminLocalization.string("admin.common.retry")) {
                        Task { await model.load() }
                    }
                }
            } else {
                List {
                    Section {
                        LabeledContent(
                            AdminLocalization.string("admin.members.total"),
                            value: model.totalElements.formatted()
                        )
                        LabeledContent(
                            AdminLocalization.string("admin.members.activeSessions"),
                            value: model.sessions.count.formatted()
                        )
                    }

                    Section(AdminLocalization.string("admin.members.title")) {
                        ForEach(model.members) { member in
                            NavigationLink {
                                AdminMemberDetailView(
                                    member: member,
                                    model: model,
                                    onOpenCalendar: onOpenCalendar
                                )
                            } label: {
                                AdminMemberRow(member: member)
                            }
                        }
                    }

                    if model.totalPages > 1 {
                        Section {
                            AdminPaginationFooter(
                                page: model.page,
                                totalPages: model.totalPages,
                                onPrevious: { Task { await model.movePage(by: -1) } },
                                onNext: { Task { await model.movePage(by: 1) } }
                            )
                        }
                    }
                }
                .refreshable { await model.load() }
            }
        }
        .navigationTitle(AdminLocalization.string("admin.nav.members"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: AdminLocalization.string("admin.members.search")
        )
        .onSubmit(of: .search) { Task { await model.search(searchText) } }
        .task { await model.load() }
        .accessibilityIdentifier("screen.admin.members")
    }
}

private struct AdminMemberRow: View {
    let member: AdminMemberDTO

    var body: some View {
        HStack(spacing: DPSpacing.compact) {
            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(DPColor.textMuted)
            VStack(alignment: .leading, spacing: 3) {
                Text(member.name)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                Text(member.email ?? AdminLocalization.string("admin.members.noEmail"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
                if let teamName = member.teamName {
                    Label(teamName, systemImage: "building.2")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textSecondary)
                }
            }
            Spacer(minLength: DPSpacing.extraSmall)
            Text(AdminLocalization.format("admin.members.sessions.count", member.tokens.count))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .frame(minHeight: 60)
    }
}

private struct AdminMemberDetailView: View {
    let member: AdminMemberDTO
    @ObservedObject var model: AdminMemberListViewModel
    let onOpenCalendar: (MemberID) -> Void
    @State private var detail: AdminMemberDetailDTO?
    @State private var isLoading = true
    @State private var loadFailed = false
    @State private var showsPasswordSheet = false
    @State private var passwordModalState = AdminModalInteractionState()
    @State private var sessionToRevoke: SettingsRefreshToken?
    @State private var operationMessage: String?

    var body: some View {
        List {
            Section {
                LabeledContent(AdminLocalization.string("admin.members.email"), value: member.email ?? "-")
                LabeledContent(AdminLocalization.string("admin.members.team"), value: member.teamName ?? "-")

                Button {
                    onOpenCalendar(member.id)
                } label: {
                    Label(AdminLocalization.string("admin.members.openCalendar"), systemImage: "calendar")
                        .frame(minHeight: DPSize.minimumTouchTarget)
                }

                Button {
                    passwordModalState = AdminModalInteractionState()
                    withoutPresentationAnimation { showsPasswordSheet = true }
                } label: {
                    Label(AdminLocalization.string("admin.members.changePassword"), systemImage: "key")
                        .frame(minHeight: DPSize.minimumTouchTarget)
                }
            }

            if isLoading {
                Section { ProgressView(AdminLocalization.string("admin.common.loading")) }
            } else if loadFailed {
                Section {
                    Button(AdminLocalization.string("admin.common.retry")) {
                        Task { await loadDetail() }
                    }
                }
            } else if let detail {
                detailSections(detail)
            }

            Section(AdminLocalization.string("admin.members.sessions")) {
                let sessions = model.sessions.filter { $0.memberId == member.id }
                if sessions.isEmpty {
                    Text(AdminLocalization.string("admin.members.sessions.empty"))
                        .foregroundStyle(DPColor.textMuted)
                } else {
                    ForEach(sessions) { token in
                        AdminSessionRow(token: token) {
                            sessionToRevoke = token
                        }
                    }
                }
            }
        }
        .navigationTitle(member.name)
        .navigationBarTitleDisplayMode(.inline)
        .task { await loadDetail() }
        .fullScreenCover(isPresented: $showsPasswordSheet) {
            DPModalOverlay(
                onDismiss: { showsPasswordSheet = false },
                closeOnBackdrop: passwordModalState.allowsBackdropDismiss,
                canDismiss: passwordModalState.allowsDismiss
            ) { availableSize, dismiss in
                AdminPasswordChangeModal(
                    member: member,
                    model: model,
                    maximumHeight: availableSize.height,
                    interactionState: $passwordModalState,
                    dismiss: dismiss
                ) {
                    operationMessage = AdminLocalization.string("admin.members.passwordChanged")
                }
            }
        }
        .confirmationDialog(
            AdminLocalization.string("admin.members.revokeSession.title"),
            isPresented: Binding(
                get: { sessionToRevoke != nil },
                set: { if !$0 { sessionToRevoke = nil } }
            )
        ) {
            Button(AdminLocalization.string("admin.members.revokeSession.action"), role: .destructive) {
                guard let token = sessionToRevoke else { return }
                Task {
                    do {
                        try await model.revokeSession(id: token.id)
                        operationMessage = AdminLocalization.string("admin.members.sessionRevoked")
                    } catch {
                        operationMessage = AdminLocalization.string("admin.members.operationFailed")
                    }
                    sessionToRevoke = nil
                }
            }
            Button(AdminLocalization.string("admin.common.cancel"), role: .cancel) {}
        }
        .alert(
            AdminLocalization.string("admin.common.notice"),
            isPresented: Binding(
                get: { operationMessage != nil },
                set: { if !$0 { operationMessage = nil } }
            )
        ) {
            Button(AdminLocalization.string("admin.common.ok"), role: .cancel) {}
        } message: {
            Text(operationMessage ?? "")
        }
    }

    @ViewBuilder
    private func detailSections(_ detail: AdminMemberDetailDTO) -> some View {
        Section(AdminLocalization.string("admin.members.account")) {
            LabeledContent(AdminLocalization.string("admin.members.role.serviceAdmin"), value: yesNo(detail.serviceAdmin))
            LabeledContent(AdminLocalization.string("admin.members.role.teamAdmin"), value: yesNo(detail.teamAdmin))
            LabeledContent(AdminLocalization.string("admin.members.role.teamManager"), value: yesNo(detail.teamManager))
            LabeledContent(AdminLocalization.string("admin.members.authProviders"), value: detail.authProviders.joined(separator: ", "))
            LabeledContent(AdminLocalization.string("admin.members.created"), value: detail.createdDate.rawValue)
            LabeledContent(AdminLocalization.string("admin.members.lastActive"), value: detail.lastActiveAt?.rawValue ?? "-")
        }

        Section(AdminLocalization.string("admin.members.activity")) {
            LabeledContent(AdminLocalization.string("admin.members.schedules"), value: detail.totalScheduleCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.upcomingSchedules"), value: detail.upcomingScheduleCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.todos"), value: detail.totalTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.overdueTodos"), value: detail.overdueTodoCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.notifications"), value: detail.totalNotificationCount.formatted())
        }

        Section(AdminLocalization.string("admin.members.relationships")) {
            LabeledContent(AdminLocalization.string("admin.members.friends"), value: detail.friendCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.family"), value: detail.familyCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.managers"), value: detail.managerCount.formatted())
            LabeledContent(AdminLocalization.string("admin.members.managedMembers"), value: detail.managedMemberCount.formatted())
        }
    }

    private func yesNo(_ value: Bool) -> String {
        AdminLocalization.string(value ? "admin.common.yes" : "admin.common.no")
    }

    private func loadDetail() async {
        isLoading = true
        defer { isLoading = false }
        do {
            detail = try await model.memberDetail(id: member.id)
            loadFailed = false
        } catch is CancellationError {
            return
        } catch {
            loadFailed = true
        }
    }
}

private struct AdminSessionRow: View {
    let token: SettingsRefreshToken
    let onRevoke: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            HStack {
                Label(
                    token.userAgent?.device ?? AdminLocalization.string("admin.members.session.unknownDevice"),
                    systemImage: "iphone"
                )
                .font(DPTypography.label)
                Spacer()
                Button(role: .destructive, action: onRevoke) {
                    Image(systemName: "xmark.circle")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .accessibilityLabel(AdminLocalization.string("admin.members.revokeSession.action"))
            }
            Text(token.userAgent.map { "\($0.os) · \($0.browser)" } ?? "-")
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            Text(token.lastUsed ?? token.createdDate ?? token.validUntil)
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
        }
        .padding(.vertical, DPSpacing.extraSmall)
    }
}

nonisolated struct AdminModalInteractionState: Equatable, Sendable {
    var isDirty = false
    var isSaving = false

    var allowsBackdropDismiss: Bool { !isDirty && !isSaving }
    var allowsDismiss: Bool { !isSaving }
}

private struct AdminPasswordChangeModal: View {
    let member: AdminMemberDTO
    @ObservedObject var model: AdminMemberListViewModel
    let maximumHeight: CGFloat
    @Binding var interactionState: AdminModalInteractionState
    let dismiss: () -> Void
    let onSuccess: () -> Void
    @State private var password = ""
    @State private var confirmation = ""
    @State private var saveFailed = false
    @FocusState private var focusedField: Field?

    private enum Field { case password, confirmation }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            header
        } content: {
            formContent
        } footer: {
            footer
        }
        .onChange(of: password) { _, _ in updateDirtyState() }
        .onChange(of: confirmation) { _, _ in updateDirtyState() }
    }

    private var header: some View {
        HStack(spacing: DPSpacing.compact) {
            VStack(alignment: .leading, spacing: 3) {
                Text(AdminLocalization.string("admin.members.changePassword"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Text(member.name)
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
            }
            Spacer()
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(interactionState.isSaving)
            .accessibilityLabel(AdminLocalization.string("admin.common.cancel"))
        }
        .padding(.horizontal, DPSpacing.large)
        .frame(minHeight: 64)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            passwordField(
                AdminLocalization.string("admin.members.newPassword"),
                text: $password,
                field: .password
            )
            passwordField(
                AdminLocalization.string("admin.members.confirmPassword"),
                text: $confirmation,
                field: .confirmation
            )

            Text(AdminLocalization.string("admin.members.passwordHint"))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if let validationMessage {
                Label(validationMessage, systemImage: "exclamationmark.circle.fill")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(DPSpacing.large)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                Task { await save() }
            } label: {
                Group {
                    if interactionState.isSaving {
                        ProgressView().tint(DPColor.textOnDark)
                    } else {
                        Text(AdminLocalization.string("admin.common.save"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!isValid || interactionState.isSaving)

            Button(action: dismiss) {
                Text(AdminLocalization.string("admin.common.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(interactionState.isSaving)
        }
        .padding(DPSpacing.compact)
    }

    private func passwordField(
        _ title: String,
        text: Binding<String>,
        field: Field
    ) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(title)
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textPrimary)
            SecureField(title, text: text)
                .textContentType(.newPassword)
                .focused($focusedField, equals: field)
                .submitLabel(field == .password ? .next : .done)
                .onSubmit {
                    focusedField = field == .password ? .confirmation : nil
                }
                .dpInputChrome(isFocused: focusedField == field)
                .disabled(interactionState.isSaving)
        }
    }

    private var isValid: Bool {
        (8...20).contains(password.count) && password == confirmation
    }

    private var validationMessage: String? {
        if saveFailed { return AdminLocalization.string("admin.members.operationFailed") }
        if !password.isEmpty && !(8...20).contains(password.count) {
            return AdminLocalization.string("admin.members.passwordLength")
        }
        if !confirmation.isEmpty && password != confirmation {
            return AdminLocalization.string("admin.members.passwordMismatch")
        }
        return nil
    }

    private func updateDirtyState() {
        interactionState.isDirty = !password.isEmpty || !confirmation.isEmpty
        saveFailed = false
    }

    private func save() async {
        interactionState.isSaving = true
        defer { interactionState.isSaving = false }
        do {
            try await model.changePassword(memberID: member.id, newPassword: password)
            onSuccess()
            dismiss()
        } catch {
            saveFailed = true
        }
    }
}

struct AdminPaginationFooter: View {
    let page: Int
    let totalPages: Int
    let onPrevious: () -> Void
    let onNext: () -> Void

    var body: some View {
        HStack {
            Button(action: onPrevious) {
                Label(AdminLocalization.string("admin.common.previous"), systemImage: "chevron.left")
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .disabled(page <= 0)
            Spacer()
            Text(AdminLocalization.format("admin.common.page", page + 1, max(totalPages, 1)))
                .font(DPTypography.label)
                .foregroundStyle(DPColor.textSecondary)
            Spacer()
            Button(action: onNext) {
                Label(AdminLocalization.string("admin.common.next"), systemImage: "chevron.right")
                    .labelStyle(.titleAndIcon)
                    .frame(minHeight: DPSize.minimumTouchTarget)
            }
            .disabled(page >= totalPages - 1)
        }
    }
}
