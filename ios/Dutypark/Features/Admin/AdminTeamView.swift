import SwiftUI

struct AdminTeamListView: View {
    @StateObject private var model: AdminTeamListViewModel
    @State private var searchText = ""
    @State private var showsCreateSheet = false
    @State private var createModalState = AdminModalInteractionState()
    @State private var teamToDelete: SimpleTeamDTO?
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
                closeOnBackdrop: createModalState.allowsBackdropDismiss,
                canDismiss: createModalState.allowsDismiss
            ) { availableSize, dismiss in
                AdminTeamCreateModal(
                    model: model,
                    maximumHeight: availableSize.height,
                    interactionState: $createModalState,
                    dismiss: dismiss
                ) { team in
                    operationMessage = AdminLocalization.format("admin.teams.created", team.name)
                    Task { await model.load() }
                }
            }
        }
        .confirmationDialog(
            AdminLocalization.string("admin.teams.delete.title"),
            isPresented: Binding(
                get: { teamToDelete != nil },
                set: { if !$0 { teamToDelete = nil } }
            )
        ) {
            Button(AdminLocalization.string("admin.common.delete"), role: .destructive) {
                guard let team = teamToDelete else { return }
                Task {
                    do {
                        try await model.delete(team)
                        operationMessage = AdminLocalization.string("admin.teams.deleted")
                    } catch {
                        operationMessage = AdminLocalization.string("admin.teams.deleteFailed")
                    }
                    teamToDelete = nil
                }
            }
            Button(AdminLocalization.string("admin.common.cancel"), role: .cancel) {}
        } message: {
            if let teamToDelete {
                Text(AdminLocalization.format("admin.teams.delete.message", teamToDelete.name))
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
    }
}

private struct AdminTeamCreateModal: View {
    @ObservedObject var model: AdminTeamListViewModel
    let maximumHeight: CGFloat
    @Binding var interactionState: AdminModalInteractionState
    let dismiss: () -> Void
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
                Task { await model.checkName(candidate) }
            } label: {
                Label(AdminLocalization.string("admin.teams.checkName"), systemImage: "checkmark.seal")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(interactionState.isSaving || name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

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

            Button(action: dismiss) {
                Text(AdminLocalization.string("admin.common.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPSecondaryButtonStyle())
            .disabled(interactionState.isSaving)
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
        defer { interactionState.isSaving = false }
        do {
            let team = try await model.create(name: name, description: description)
            onCreated(team)
            dismiss()
        } catch {
            saveFailed = true
        }
    }

    private func updateDirtyState() {
        interactionState.isDirty = !name.isEmpty || !description.isEmpty
    }
}
