import SwiftUI

struct AdminTeamListView: View {
    @StateObject private var model: AdminTeamListViewModel
    @State private var searchText = ""
    @State private var showsCreateSheet = false
    @State private var createModalState = AdminModalInteractionState()
    @State private var showsCreateDiscardConfirmation = false
    @State private var createdTeamID: TeamID?

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
                        AdminTeamListSummary(
                            searchKeyword: model.searchKeyword,
                            totalElements: model.totalElements,
                            clearSearch: clearSearch
                        )
                    }
                    .listRowSeparator(.hidden)

                    Section {
                        if model.teams.isEmpty {
                            AdminTeamEmptyState()
                        } else {
                            ForEach(model.teams, id: \.id) { team in
                                NavigationLink {
                                    teamManageDestination(team.id)
                                } label: {
                                    AdminTeamRow(team: team)
                                }
                            }
                        }
                    }

                    if model.totalPages > 1 {
                        Section {
                            AdminTeamPagination(
                                page: model.page,
                                totalPages: model.totalPages,
                                selectPage: { page in
                                    Task { await model.movePage(to: page) }
                                }
                            )
                        }
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
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
        .onChange(of: searchText) { oldValue, newValue in
            guard !oldValue.isEmpty,
                  newValue.isEmpty,
                  !model.searchKeyword.isEmpty
            else { return }
            Task { await model.search("") }
        }
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
                .accessibilityIdentifier("admin.teams.create.open")
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
                    showsCreateSheet = false
                    createdTeamID = team.id
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
        .task { await model.load() }
        .navigationDestination(item: $createdTeamID) { teamID in
            teamManageDestination(teamID)
        }
        .accessibilityIdentifier("screen.admin.teams")
    }

    private func clearSearch() {
        if searchText.isEmpty {
            Task { await model.search("") }
        } else {
            searchText = ""
        }
    }

    private func teamManageDestination(_ teamID: TeamID) -> some View {
        TeamManageView(
            teamID: teamID,
            isServiceAdmin: true,
            onDeleteTeam: { team in
                try await model.delete(
                    SimpleTeamDTO(
                        id: team.id,
                        name: team.name,
                        description: team.description,
                        memberCount: Int64(team.members.count)
                    )
                )
            }
        )
            .accessibilityIdentifier("screen.team.manage.\(teamID)")
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

}

private struct AdminTeamListSummary: View {
    let searchKeyword: String
    let totalElements: Int64
    let clearSearch: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
            Text(AdminLocalization.string("admin.teams.title"))
                .font(DPTypography.sectionTitle)
                .foregroundStyle(DPColor.textPrimary)

            HStack(alignment: .center, spacing: DPSpacing.extraSmall) {
                if !searchKeyword.isEmpty {
                    Text("[\(searchKeyword)]")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.accent)
                }
                Text(AdminLocalization.format("admin.teams.total", totalElements))
                    .font(DPTypography.supporting)
                    .foregroundStyle(DPColor.textSecondary)
                Spacer(minLength: DPSpacing.extraSmall)
                if !searchKeyword.isEmpty {
                    Button(action: clearSearch) {
                        Label(
                            AdminLocalization.string("admin.teams.search.clear"),
                            systemImage: "xmark.circle.fill"
                        )
                        .font(DPTypography.supporting)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.textSecondary)
                    .accessibilityIdentifier("admin.teams.search.clear")
                }
            }
        }
        .padding(.vertical, DPSpacing.extraSmall)
    }
}

struct AdminTeamEmptyState: View {
    var body: some View {
        ContentUnavailableView {
            Label {
                Text(AdminLocalization.string("admin.teams.empty"))
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textMuted)
            } icon: {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 28, weight: .medium))
                    .foregroundStyle(DPColor.textMuted)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132)
        .accessibilityIdentifier("admin.teams.empty")
    }
}

nonisolated enum AdminTeamPaginationItem: Equatable, Sendable {
    case page(Int)
    case gap
}

nonisolated enum AdminTeamPaginationPolicy {
    static func items(currentPage: Int, totalPages: Int) -> [AdminTeamPaginationItem] {
        guard totalPages > 0 else { return [] }
        if totalPages <= 5 {
            return (0..<totalPages).map(AdminTeamPaginationItem.page)
        }

        let pages = Set([0, totalPages - 1, currentPage - 1, currentPage, currentPage + 1])
            .filter { (0..<totalPages).contains($0) }
            .sorted()
        return items(for: pages)
    }

    static func compactItems(currentPage: Int, totalPages: Int) -> [AdminTeamPaginationItem] {
        guard totalPages > 0 else { return [] }
        let pages = Set([0, currentPage, totalPages - 1])
            .filter { (0..<totalPages).contains($0) }
            .sorted()
        return items(for: pages)
    }

    private static func items(for pages: [Int]) -> [AdminTeamPaginationItem] {
        var items: [AdminTeamPaginationItem] = []
        for page in pages {
            if case .page(let previous)? = items.last, page - previous > 1 {
                items.append(.gap)
            }
            items.append(.page(page))
        }
        return items
    }
}

private struct AdminTeamPagination: View {
    let page: Int
    let totalPages: Int
    let selectPage: (Int) -> Void

    var body: some View {
        ViewThatFits(in: .horizontal) {
            paginationRow(
                items: AdminTeamPaginationPolicy.items(currentPage: page, totalPages: totalPages)
            )
            paginationRow(
                items: AdminTeamPaginationPolicy.compactItems(currentPage: page, totalPages: totalPages)
            )
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DPSpacing.extraSmall)
    }

    private func paginationRow(items: [AdminTeamPaginationItem]) -> some View {
        HStack(spacing: DPSpacing.extraSmall) {
            pageButton(systemImage: "chevron.left", page: page - 1)
                .disabled(page == 0)
                .accessibilityLabel(AdminLocalization.string("admin.common.previous"))

            ForEach(
                Array(items.enumerated()),
                id: \.offset
            ) { _, item in
                switch item {
                case .gap:
                    Text("…")
                        .font(DPTypography.label)
                        .foregroundStyle(DPColor.textMuted)
                        .frame(minWidth: 20, minHeight: DPSize.minimumTouchTarget)
                case .page(let itemPage):
                    Button {
                        selectPage(itemPage)
                    } label: {
                        Text("\(itemPage + 1)")
                            .font(DPTypography.label)
                            .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                            .foregroundStyle(itemPage == page ? DPColor.textOnDark : DPColor.textSecondary)
                            .background(
                                itemPage == page ? DPColor.surfaceStrong : Color.clear,
                                in: RoundedRectangle(cornerRadius: DPRadius.standard)
                            )
                    }
                    .buttonStyle(.plain)
                    .disabled(itemPage == page)
                    .accessibilityIdentifier("admin.teams.page.\(itemPage + 1)")
                }
            }

            pageButton(systemImage: "chevron.right", page: page + 1)
                .disabled(page >= totalPages - 1)
                .accessibilityLabel(AdminLocalization.string("admin.common.next"))
        }
    }

    private func pageButton(systemImage: String, page: Int) -> some View {
        Button {
            selectPage(page)
        } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
        }
        .buttonStyle(.plain)
        .foregroundStyle(DPColor.textMuted)
    }
}

private struct AdminTeamRow: View {
    let team: SimpleTeamDTO

    var body: some View {
        HStack(alignment: .top, spacing: DPSpacing.compact) {
            Image(systemName: "building.2.fill")
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: 40, height: 40)
                .background(DPColor.backgroundTertiary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
            VStack(alignment: .leading, spacing: 3) {
                Text(team.name)
                    .font(DPTypography.label)
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(team.description ?? AdminLocalization.string("admin.teams.noDescription"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: DPSpacing.extraSmall)
            Label(
                AdminLocalization.format("admin.teams.members.count", team.memberCount),
                systemImage: "person.2"
            )
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
                    .accessibilityIdentifier("admin.teams.create.name")
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
            .accessibilityIdentifier("admin.teams.create.checkName")

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
                .accessibilityIdentifier("admin.teams.create.description")
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
            .accessibilityIdentifier("admin.teams.create.submit")

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
