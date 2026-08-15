import SwiftUI

struct AdminTeamListView: View {
    @StateObject private var model: AdminTeamListViewModel
    @State private var searchText = ""
    @State private var showsCreateSheet = false
    @State private var createModalState = AdminModalInteractionState()
    @State private var showsCreateDiscardConfirmation = false
    @State private var teamToDelete: SimpleTeamDTO?
    @State private var isDeletingTeam = false
    @State private var operationMessage: String?

    init(model: @autoclosure @escaping () -> AdminTeamListViewModel = AdminTeamListViewModel()) {
        _model = StateObject(wrappedValue: model())
    }

    var body: some View {
        Group {
            if model.isLoading && model.teams.isEmpty {
                ProgressView(AdminLocalization.string("admin.common.loading"))
            } else if model.loadFailed && model.teams.isEmpty {
                ContentUnavailableView {
                    Label(AdminLocalization.string("admin.teams.loadFailed"), systemImage: "wifi.exclamationmark")
                } actions: {
                    Button(AdminLocalization.string("admin.common.retry")) {
                        Task { await model.load() }
                    }
                }
            } else {
                List {
                    Section {
                        LabeledContent(
                            AdminLocalization.string("admin.teams.total"),
                            value: model.totalElements.formatted()
                        )
                    }

                    Section(AdminLocalization.string("admin.teams.title")) {
                        ForEach(model.teams, id: \.id) { team in
                            NavigationLink {
                                TeamManageView(teamID: team.id, isServiceAdmin: true)
                            } label: {
                                AdminTeamRow(team: team)
                            }
                            .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                Button(role: .destructive) {
                                    teamToDelete = team
                                } label: {
                                    Label(AdminLocalization.string("admin.common.delete"), systemImage: "trash")
                                }
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
        .navigationTitle(AdminLocalization.string("admin.nav.teams"))
        .navigationBarTitleDisplayMode(.inline)
        .searchable(
            text: $searchText,
            placement: .navigationBarDrawer(displayMode: .always),
            prompt: AdminLocalization.string("admin.teams.search")
        )
        .onSubmit(of: .search) { Task { await model.search(searchText) } }
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    model.resetNameCheck()
                    createModalState = AdminModalInteractionState()
                    withoutPresentationAnimation { showsCreateSheet = true }
                } label: {
                    Image(systemName: "plus")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .accessibilityLabel(AdminLocalization.string("admin.teams.create"))
            }
        }
        .fullScreenCover(isPresented: $showsCreateSheet) {
            DPModalOverlay(
                onDismiss: { showsCreateSheet = false },
                canDismiss: createModalState.allowsDismiss,
                onDismissRequest: { _ in requestCreateModalDismiss() }
            ) { availableSize, _ in
                AdminTeamCreateModal(
                    model: model,
                    maximumHeight: availableSize.height,
                    interactionState: $createModalState,
                    requestDismiss: requestCreateModalDismiss
                ) { team in
                    operationMessage = AdminLocalization.format("admin.teams.created", team.name)
                    showsCreateSheet = false
                }
            }
            .alert(
                AdminLocalization.string("admin.common.discard.title"),
                isPresented: $showsCreateDiscardConfirmation
            ) {
                Button(AdminLocalization.string("admin.common.discard.action"), role: .destructive) {
                    showsCreateSheet = false
                }
                Button(AdminLocalization.string("admin.common.discard.continue"), role: .cancel) {}
            } message: {
                Text(AdminLocalization.string("admin.common.discard.message"))
            }
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { teamToDelete != nil },
                set: {
                    if !$0 && !isDeletingTeam {
                        teamToDelete = nil
                    }
                }
            )
        ) {
            if let teamToDelete {
                DPModalOverlay(
                    maximumContentWidth: DPConfirmationPanel.maximumWidth,
                    onDismiss: { self.teamToDelete = nil },
                    canDismiss: !isDeletingTeam
                ) { availableSize, dismiss in
                    DPConfirmationPanel(
                        title: AdminLocalization.string("admin.teams.delete.title"),
                        message: AdminLocalization.format("admin.teams.delete.message", teamToDelete.name),
                        confirmTitle: AdminLocalization.string("admin.common.delete"),
                        cancelTitle: AdminLocalization.string("admin.common.cancel"),
                        isDestructive: true,
                        isWorking: isDeletingTeam,
                        maximumHeight: availableSize.height,
                        cancel: dismiss,
                        confirm: {
                            delete(teamToDelete, dismiss: dismiss)
                        }
                    )
                }
            }
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
        .task { await model.load() }
        .accessibilityIdentifier("screen.admin.teams")
    }

    private func requestCreateModalDismiss() {
        switch createModalState.dismissDecision {
        case .dismiss:
            showsCreateSheet = false
        case .confirmDiscard:
            showsCreateDiscardConfirmation = true
        case .blocked:
            break
        }
    }

    private func delete(_ team: SimpleTeamDTO, dismiss: @escaping () -> Void) {
        guard AdminTeamDeleteConfirmationPolicy.canSubmit(isDeleting: isDeletingTeam) else { return }
        isDeletingTeam = true

        Task {
            do {
                try await model.delete(team)
                operationMessage = AdminLocalization.string("admin.teams.deleted")
            } catch {
                operationMessage = AdminLocalization.string("admin.teams.deleteFailed")
            }
            isDeletingTeam = false
            dismiss()
        }
    }
}

nonisolated enum AdminTeamDeleteConfirmationPolicy {
    static func canSubmit(isDeleting: Bool) -> Bool {
        !isDeleting
    }
}

private struct AdminTeamRow: View {
    let team: SimpleTeamDTO

    var body: some View {
        HStack(spacing: DPSpacing.compact) {
            Image(systemName: "building.2.crop.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(DPColor.success)
            VStack(alignment: .leading, spacing: 3) {
                Text(team.name)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                Text(team.description ?? AdminLocalization.string("admin.teams.noDescription"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(2)
            }
            Spacer(minLength: DPSpacing.extraSmall)
            Text(AdminLocalization.format("admin.teams.members.count", team.memberCount))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textSecondary)
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .frame(minHeight: 60)
        .accessibilityIdentifier("admin.team.\(team.id)")
    }
}

private struct AdminTeamCreateModal: View {
    @ObservedObject var model: AdminTeamListViewModel
    let maximumHeight: CGFloat
    @Binding var interactionState: AdminModalInteractionState
    let requestDismiss: () -> Void
    let onCreated: (TeamDTO) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var checkedName: String?
    @State private var saveFailed = false
    @FocusState private var focusedField: Field?

    private enum Field { case name, description }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight) {
            header
        } content: {
            formContent
        } footer: {
            footer
        }
        .onChange(of: name) { _, _ in
            checkedName = nil
            model.resetNameCheck()
            saveFailed = false
            updateDirtyState()
        }
        .onChange(of: description) { _, _ in
            saveFailed = false
            updateDirtyState()
        }
    }

    private var header: some View {
        HStack {
            Text(AdminLocalization.string("admin.teams.create"))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer()
            Button(action: requestDismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(DPColor.textMuted)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .background(DPColor.backgroundTertiary, in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(interactionState.isWorking)
            .accessibilityLabel(AdminLocalization.string("admin.common.cancel"))
        }
        .padding(.horizontal, DPSpacing.large)
        .frame(minHeight: 64)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack {
                    Text(AdminLocalization.string("admin.teams.name"))
                        .font(DPTypography.label)
                    Spacer()
                    Text("\(name.count)/20")
                        .font(DPTypography.caption)
                        .foregroundStyle(name.count > 20 ? DPColor.danger : DPColor.textMuted)
                }
                TextField(AdminLocalization.string("admin.teams.name"), text: $name)
                    .textInputAutocapitalization(.never)
                    .focused($focusedField, equals: .name)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .description }
                    .dpInputChrome(
                        isFocused: focusedField == .name,
                        isInvalid: name.count > 20
                    )
                    .disabled(interactionState.isSaving)
            }

            Button {
                let candidate = normalizedName
                checkedName = candidate
                interactionState.isChecking = true
                Task {
                    await model.checkName(candidate)
                    interactionState.isChecking = false
                }
            } label: {
                Label(AdminLocalization.string("admin.teams.checkName"), systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(interactionState.isWorking || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            if checkedName == normalizedName, let result = model.nameCheckResult {
                Label(
                    nameCheckMessage(result),
                    systemImage: result == .ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
                )
                .font(DPTypography.supporting)
                .foregroundStyle(result == .ok ? DPColor.success : DPColor.danger)
            }

            VStack(alignment: .leading, spacing: DPSpacing.small) {
                HStack {
                    Text(AdminLocalization.string("admin.teams.description"))
                        .font(DPTypography.label)
                    Spacer()
                    Text("\(description.count)/50")
                        .font(DPTypography.caption)
                        .foregroundStyle(description.count > 50 ? DPColor.danger : DPColor.textMuted)
                }
                TextField(
                    AdminLocalization.string("admin.teams.description"),
                    text: $description,
                    axis: .vertical
                )
                .lineLimit(2...4)
                .focused($focusedField, equals: .description)
                .dpInputChrome(
                    isFocused: focusedField == .description,
                    isInvalid: description.count > 50
                )
                .disabled(interactionState.isSaving)
            }

            Text(AdminLocalization.string("admin.teams.createHint"))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .fixedSize(horizontal: false, vertical: true)

            if saveFailed {
                Label(AdminLocalization.string("admin.teams.createFailed"), systemImage: "exclamationmark.circle.fill")
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.danger)
            }
        }
        .padding(DPSpacing.large)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                Task { await create() }
            } label: {
                Group {
                    if interactionState.isSaving {
                        ProgressView().tint(DPColor.textOnDark)
                    } else {
                        Text(AdminLocalization.string("admin.common.create"))
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!canCreate || interactionState.isSaving)

            Button(action: requestDismiss) {
                Text(AdminLocalization.string("admin.common.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(interactionState.isWorking)
        }
        .padding(DPSpacing.compact)
    }

    private var canCreate: Bool {
        checkedName == normalizedName
            && model.nameCheckResult == .ok
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && description.count <= 50
    }

    private var normalizedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func nameCheckMessage(_ result: AdminTeamNameCheckResult) -> String {
        switch result {
        case .ok: AdminLocalization.string("admin.teams.nameCheck.ok")
        case .duplicated: AdminLocalization.string("admin.teams.nameCheck.duplicated")
        case .tooLong: AdminLocalization.string("admin.teams.nameCheck.tooLong")
        case .tooShort: AdminLocalization.string("admin.teams.nameCheck.tooShort")
        }
    }

    private func create() async {
        interactionState.isSaving = true
        do {
            let team = try await model.create(name: name, description: description)
            interactionState.isSaving = false
            onCreated(team)
        } catch {
            interactionState.isSaving = false
            saveFailed = true
        }
    }

    private func updateDirtyState() {
        interactionState.isDirty = AdminModalInteractionState.teamIsDirty(
            name: name,
            description: description
        )
    }
}
