import SwiftUI

struct AdminTeamListView: View {
    @StateObject private var model: AdminTeamListViewModel
    @State private var searchText = ""
    @State private var showsCreateSheet = false
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
                    showsCreateSheet = true
                } label: {
                    Image(systemName: "plus")
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .accessibilityLabel(AdminLocalization.string("admin.teams.create"))
            }
        }
        .sheet(isPresented: $showsCreateSheet) {
            AdminTeamCreateSheet(model: model) { team in
                showsCreateSheet = false
                operationMessage = AdminLocalization.format("admin.teams.created", team.name)
                Task { await model.load() }
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

private struct AdminTeamCreateSheet: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var model: AdminTeamListViewModel
    let onCreated: (TeamDTO) -> Void
    @State private var name = ""
    @State private var description = ""
    @State private var isSaving = false
    @State private var saveFailed = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(AdminLocalization.string("admin.teams.name"), text: $name)
                        .textInputAutocapitalization(.never)
                        .onChange(of: name) { _, _ in model.resetNameCheck() }
                    TextField(
                        AdminLocalization.string("admin.teams.description"),
                        text: $description,
                        axis: .vertical
                    )
                    .lineLimit(2...4)
                } footer: {
                    Text(AdminLocalization.string("admin.teams.createHint"))
                }

                Section {
                    Button {
                        Task { await model.checkName(name) }
                    } label: {
                        Label(AdminLocalization.string("admin.teams.checkName"), systemImage: "checkmark.seal")
                            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    }

                    if let result = model.nameCheckResult {
                        Label(nameCheckMessage(result), systemImage: result == .ok ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                            .foregroundStyle(result == .ok ? DPColor.success : DPColor.danger)
                    }
                }

                if saveFailed {
                    Section {
                        Text(AdminLocalization.string("admin.teams.createFailed"))
                            .foregroundStyle(DPColor.danger)
                    }
                }
            }
            .navigationTitle(AdminLocalization.string("admin.teams.create"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(AdminLocalization.string("admin.common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(AdminLocalization.string("admin.common.create")) {
                        Task { await create() }
                    }
                    .disabled(!canCreate || isSaving)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var canCreate: Bool {
        model.nameCheckResult == .ok
            && !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && description.count <= 50
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
        isSaving = true
        defer { isSaving = false }
        do {
            let team = try await model.create(name: name, description: description)
            onCreated(team)
        } catch {
            saveFailed = true
        }
    }
}
