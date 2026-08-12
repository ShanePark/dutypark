import SwiftUI
import UniformTypeIdentifiers

struct TeamManageView: View {
    @EnvironmentObject private var session: SessionStore
    @StateObject private var viewModel: TeamManageViewModel
    @State private var pendingAction: PendingAction?

    init(teamID: TeamID) {
        _viewModel = StateObject(wrappedValue: TeamManageViewModel(teamID: teamID))
    }

    private var loginID: MemberID? {
        if case .authenticated(let member) = session.state { member.id } else { nil }
    }

    var body: some View {
        Group {
            if viewModel.isLoading && viewModel.team == nil {
                DPLoadingState(label: LocalizedStringKey(teamLocalized("team.common.loading")))
            } else if let team = viewModel.team {
                List {
                    informationSection(team)
                    membersSection(team)
                    dutyTypesSection(team)
                }
                .listStyle(.insetGrouped)
            } else {
                DPErrorState(
                    title: LocalizedStringKey(teamLocalized("team.common.error")),
                    message: nil,
                    retryTitle: LocalizedStringKey(teamLocalized("team.common.retry"))
                ) {
                    Task { await viewModel.load() }
                }
            }
        }
        .navigationTitle(viewModel.team?.name ?? teamLocalized("team.manage.fields.name"))
        .navigationBarTitleDisplayMode(.inline)
        .task { await viewModel.load() }
        .disabled(viewModel.isWorking)
        .overlay {
            if viewModel.isWorking {
                ProgressView()
                    .padding(DPSpacing.medium)
                    .background(.regularMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
        .sheet(isPresented: $viewModel.memberSearchPresented, onDismiss: {
            Task { await viewModel.load() }
        }) {
            TeamMemberSearchView(teamID: viewModel.teamID)
        }
        .sheet(isPresented: $viewModel.dutyEditorPresented) {
            TeamDutyTypeEditor(viewModel: viewModel)
        }
        .sheet(isPresented: $viewModel.batchUploadPresented) {
            TeamBatchUploadView(viewModel: viewModel)
        }
        .alert(
            Text("team.common.error", tableName: "Team"),
            isPresented: $viewModel.showsError
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        } message: {
            Text("team.common.error", tableName: "Team")
        }
        .alert(
            Text("team.manage.messages.updateSuccess", tableName: "Team"),
            isPresented: $viewModel.showsSuccess
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        }
        .confirmationDialog(
            Text("team.common.confirm", tableName: "Team"),
            isPresented: Binding(
                get: { pendingAction != nil },
                set: { if !$0 { pendingAction = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button(teamLocalized("team.common.confirm"), role: pendingAction?.isDestructive == true ? .destructive : nil) {
                let action = pendingAction
                pendingAction = nil
                Task { await run(action) }
            }
            Button(teamLocalized("team.common.cancel"), role: .cancel) { pendingAction = nil }
        }
    }

    private func informationSection(_ team: TeamDTO) -> some View {
        Section {
            LabeledContent(teamLocalized("team.manage.fields.name"), value: team.name)
            LabeledContent(
                teamLocalized("team.manage.fields.description"),
                value: team.description ?? teamLocalized("team.manage.labels.notAvailable")
            )
            if viewModel.canUseAdminTools(loginID: loginID) {
                HStack {
                    LabeledContent(
                        teamLocalized("team.manage.fields.admin"),
                        value: team.adminName ?? teamLocalized("team.manage.labels.notAvailable")
                    )
                    if team.adminId != nil, team.adminId != loginID {
                        Button(role: .destructive) {
                            pendingAction = .changeAdmin(nil)
                        } label: {
                            Image(systemName: "xmark.circle")
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        }
                            .accessibilityLabel(Text("team.manage.actions.resetAdmin", tableName: "Team"))
                    }
                }
            }
            Picker(
                teamLocalized("team.manage.fields.batchTemplate"),
                selection: Binding(
                    get: { team.dutyBatchTemplate?.name ?? "" },
                    set: { name in Task { await viewModel.updateTemplate(name.isEmpty ? nil : name) } }
                )
            ) {
                Text("team.manage.labels.none", tableName: "Team").tag("")
                ForEach(viewModel.templates, id: \.name) { template in
                    Text(verbatim: template.label).tag(template.name)
                }
            }
            if team.dutyBatchTemplate != nil {
                Button {
                    viewModel.batchUploadPresented = true
                } label: {
                    Label {
                        Text("team.manage.actions.upload", tableName: "Team")
                    } icon: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
        } header: {
            Text("team.manage.fields.name", tableName: "Team")
        }
    }

    private func membersSection(_ team: TeamDTO) -> some View {
        Section {
            if team.members.isEmpty {
                Text("team.manage.labels.noMembers", tableName: "Team")
                    .foregroundStyle(DPColor.textMuted)
            }
            ForEach(team.members, id: \.id) { member in
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    HStack {
                        Image(systemName: member.isAdmin ? "crown.fill" : member.isManager ? "checkmark.shield.fill" : "person.fill")
                            .foregroundStyle(member.isAdmin ? DPColor.warning : member.isManager ? DPColor.success : DPColor.textMuted)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: member.name).font(.body.weight(.medium))
                            if let email = member.email {
                                Text(verbatim: email).font(.caption).foregroundStyle(DPColor.textMuted)
                            }
                        }
                        Spacer()
                        Menu {
                            if let id = member.id {
                                if viewModel.canUseAdminTools(loginID: loginID), !member.isAdmin {
                                    if member.isManager {
                                        Button {
                                            pendingAction = .removeManager(id)
                                        } label: {
                                            Label(teamLocalized("team.manage.actions.revokeManager"), systemImage: "shield.slash")
                                        }
                                        Button {
                                            pendingAction = .changeAdmin(id)
                                        } label: {
                                            Label(teamLocalized("team.manage.actions.transferAdmin"), systemImage: "crown")
                                        }
                                    } else {
                                        Button {
                                            pendingAction = .addManager(id)
                                        } label: {
                                            Label(teamLocalized("team.manage.actions.assignManager"), systemImage: "shield")
                                        }
                                    }
                                }
                                Button(role: .destructive) {
                                    pendingAction = .removeMember(id)
                                } label: {
                                    Label(teamLocalized("team.manage.actions.removeMember"), systemImage: "trash")
                                }
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        }
                    }
                }
            }
        } header: {
            HStack {
                Text("team.manage.fields.members", tableName: "Team")
                Spacer()
                Button {
                    viewModel.memberSearchPresented = true
                } label: {
                    Label {
                        Text("team.manage.actions.addMember", tableName: "Team")
                    } icon: {
                        Image(systemName: "person.badge.plus")
                    }
                }
                .textCase(nil)
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
        }
    }

    private func dutyTypesSection(_ team: TeamDTO) -> some View {
        Section {
            if team.dutyTypes.isEmpty {
                Text("team.manage.labels.noDutyTypes", tableName: "Team")
                    .foregroundStyle(DPColor.textMuted)
            }
            ForEach(Array(team.dutyTypes.enumerated()), id: \.offset) { index, dutyType in
                HStack(spacing: DPSpacing.small) {
                    Circle()
                        .fill(Color(teamHex: dutyType.color))
                        .frame(width: 24, height: 24)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: dutyType.name)
                        Text(
                            dutyType.hidden
                                ? "team.manage.labels.hidden"
                                : dutyType.id == nil
                                    ? "team.manage.labels.offDuty"
                                    : "team.manage.labels.visible",
                            tableName: "Team"
                        )
                        .font(.caption)
                        .foregroundStyle(DPColor.textMuted)
                    }
                    Spacer()
                    Menu {
                        Button {
                            viewModel.editingDutyType = dutyType
                            viewModel.dutyEditorPresented = true
                        } label: {
                            Label(teamLocalized("team.dutyType.actions.edit"), systemImage: "pencil")
                        }
                        if dutyType.id != nil {
                            Button {
                                Task { await viewModel.moveDutyType(from: index, direction: -1) }
                            } label: {
                                Label(teamLocalized("team.dutyType.actions.saveOrder"), systemImage: "arrow.up")
                            }
                            .disabled(
                                TeamFeatureLogic.visibleDutyTypeNeighbor(
                                    in: team.dutyTypes,
                                    from: index,
                                    direction: -1
                                ) == nil
                            )
                            Button {
                                Task { await viewModel.moveDutyType(from: index, direction: 1) }
                            } label: {
                                Label(teamLocalized("team.dutyType.actions.saveOrder"), systemImage: "arrow.down")
                            }
                            .disabled(
                                TeamFeatureLogic.visibleDutyTypeNeighbor(
                                    in: team.dutyTypes,
                                    from: index,
                                    direction: 1
                                ) == nil
                            )
                            Button {
                                Task { await viewModel.toggleVisibility(dutyType) }
                            } label: {
                                Label(
                                    dutyType.hidden
                                        ? teamLocalized("team.manage.actions.restoreDutyType")
                                        : teamLocalized("team.manage.actions.hideDutyType"),
                                    systemImage: dutyType.hidden ? "eye" : "eye.slash"
                                )
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    }
                }
                .opacity(dutyType.hidden ? 0.6 : 1)
            }
        } header: {
            HStack {
                Text("team.manage.fields.dutyTypes", tableName: "Team")
                Spacer()
                Button {
                    viewModel.editingDutyType = nil
                    viewModel.dutyEditorPresented = true
                } label: {
                    Label {
                        Text("team.manage.actions.addDutyType", tableName: "Team")
                    } icon: {
                        Image(systemName: "plus")
                    }
                }
                .textCase(nil)
                .frame(minHeight: DPSize.minimumTouchTarget)
            }
        }
    }

    private func run(_ action: PendingAction?) async {
        switch action {
        case .removeMember(let id): await viewModel.removeMember(id)
        case .addManager(let id): await viewModel.addManager(id)
        case .removeManager(let id): await viewModel.removeManager(id)
        case .changeAdmin(let id): await viewModel.changeAdmin(memberID: id)
        case nil: break
        }
    }

    private enum PendingAction: Equatable {
        case removeMember(MemberID)
        case addManager(MemberID)
        case removeManager(MemberID)
        case changeAdmin(MemberID?)

        var isDestructive: Bool {
            switch self {
            case .removeMember, .removeManager, .changeAdmin(nil): true
            case .addManager, .changeAdmin: false
            }
        }
    }
}

private struct TeamDutyTypeEditor: View {
    @ObservedObject var viewModel: TeamManageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var color = Color.blue

    var body: some View {
        NavigationStack {
            Form {
                TextField(teamLocalized("team.dutyType.placeholders.name"), text: $name)
                ColorPicker(teamLocalized("team.manage.fields.color"), selection: $color, supportsOpacity: false)
            }
            .navigationTitle(Text(viewModel.editingDutyType == nil ? "team.dutyType.titleAdd" : "team.dutyType.titleEdit", tableName: "Team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(teamLocalized("team.common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(teamLocalized("team.common.save")) {
                        Task {
                            await viewModel.saveDutyType(name: name, color: color.teamHexRGB)
                            if !viewModel.showsError { dismiss() }
                        }
                    }
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                if let dutyType = viewModel.editingDutyType {
                    name = dutyType.name
                    color = Color(teamHex: dutyType.color)
                }
            }
        }
        .presentationDetents([.medium])
    }
}

private struct TeamMemberSearchView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: TeamMemberSearchViewModel

    init(teamID: TeamID) {
        _viewModel = StateObject(wrappedValue: TeamMemberSearchViewModel(teamID: teamID))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(viewModel.results, id: \.id) { member in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(verbatim: member.name)
                            if let email = member.email {
                                Text(verbatim: email).font(.caption).foregroundStyle(DPColor.textMuted)
                            }
                        }
                        Spacer()
                        Button(teamLocalized("team.memberSearch.add")) {
                            Task { if await viewModel.add(member) { dismiss() } }
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(member.teamId != nil)
                    }
                }
                if !viewModel.results.isEmpty {
                    HStack {
                        Button {
                            Task { await viewModel.previousPage() }
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        }
                        .disabled(!viewModel.canLoadPreviousPage)
                        Spacer()
                        Text(
                            String(
                                format: teamLocalized("team.memberSearch.pagination"),
                                locale: AppLocalization.locale,
                                Int64(viewModel.currentPage + 1),
                                Int64(viewModel.totalPages),
                                viewModel.totalElements
                            )
                        )
                        .font(.caption)
                        .foregroundStyle(DPColor.textMuted)
                        Spacer()
                        Button {
                            Task { await viewModel.nextPage() }
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        }
                        .disabled(!viewModel.canLoadNextPage)
                    }
                }
            }
            .searchable(
                text: $viewModel.keyword,
                prompt: Text("team.memberSearch.searchPlaceholder", tableName: "Team")
            )
            .onSubmit(of: .search) { Task { await viewModel.search(resetPage: true) } }
            .task { await viewModel.search(resetPage: true) }
            .overlay {
                if viewModel.isWorking { ProgressView() }
                else if viewModel.results.isEmpty {
                    ContentUnavailableView(
                        teamLocalized("team.memberSearch.empty"),
                        systemImage: "person.crop.circle.badge.questionmark"
                    )
                }
            }
            .navigationTitle(Text("team.memberSearch.title", tableName: "Team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(teamLocalized("team.common.cancel")) { dismiss() }
                }
            }
            .alert(
                Text("team.common.error", tableName: "Team"),
                isPresented: $viewModel.showsError
            ) {
                Button(teamLocalized("team.common.confirm"), role: .cancel) {}
            }
        }
    }
}

private struct TeamBatchUploadView: View {
    @ObservedObject var viewModel: TeamManageViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var fileURL: URL?
    @State private var fileImporterPresented = false
    @State private var result: TeamBatchResultDTO?

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        NavigationStack {
            Form {
                Picker(teamLocalized("team.batchUpload.year"), selection: $year) {
                    ForEach(currentYear...(currentYear + 1), id: \.self) { value in
                        Text(verbatim: String(value)).tag(value)
                    }
                }
                Picker(teamLocalized("team.batchUpload.month"), selection: $month) {
                    ForEach(1...12, id: \.self) { Text(verbatim: String($0)).tag($0) }
                }
                Button {
                    fileImporterPresented = true
                } label: {
                    Label {
                        Text("team.batchUpload.selectFile", tableName: "Team")
                    } icon: {
                        Image(systemName: "doc.badge.plus")
                    }
                }
                if let fileURL {
                    Text(verbatim: fileURL.lastPathComponent)
                        .font(.subheadline)
                }
                if let result {
                    Section {
                        if let period = batchPeriod(result.startDate, result.endDate) {
                            LabeledContent(teamLocalized("team.batchUpload.period"), value: period)
                        }
                        if !result.result {
                            Text(verbatim: batchMessage(result.errorCode, result.errorDetails))
                                .foregroundStyle(DPColor.danger)
                        }
                        ForEach(Array(result.dutyBatchResult.enumerated()), id: \.offset) { _, item in
                            VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                                LabeledContent(
                                    item.memberName,
                                    value: item.result.result
                                        ? teamLocalized("team.batchUpload.success")
                                        : batchMessage(item.result.errorCode, item.result.errorDetails)
                                )
                                if let period = batchPeriod(item.result.startDate, item.result.endDate) {
                                    Text(verbatim: period)
                                        .font(.caption)
                                        .foregroundStyle(DPColor.textSecondary)
                                }
                            }
                        }
                    } header: {
                        Text("team.batchUpload.result", tableName: "Team")
                    }
                }
            }
            .navigationTitle(Text("team.batchUpload.title", tableName: "Team"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(teamLocalized("team.common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(teamLocalized("team.manage.actions.upload")) {
                        guard let fileURL,
                              TeamFeatureLogic.isValidDutyBatchYear(year, currentYear: currentYear)
                        else { return }
                        Task { result = await viewModel.upload(fileURL: fileURL, year: year, month: month) }
                    }
                    .disabled(
                        fileURL == nil
                            || !TeamFeatureLogic.isValidDutyBatchYear(year, currentYear: currentYear)
                            || viewModel.isWorking
                    )
                }
            }
            .fileImporter(
                isPresented: $fileImporterPresented,
                allowedContentTypes: [UTType(filenameExtension: "xlsx") ?? .spreadsheet],
                allowsMultipleSelection: false
            ) { selection in
                guard let selectedURL = try? selection.get().first,
                      TeamFeatureLogic.isValidDutyBatchFileName(selectedURL.lastPathComponent)
                else {
                    fileURL = nil
                    return
                }
                fileURL = selectedURL
            }
        }
    }

    private func batchMessage(_ code: String?, _ details: [String: JSONValue]?) -> String {
        APIErrorLocalization.message(code: code, details: details)
    }

    private func batchPeriod(_ startDate: DateOnly?, _ endDate: DateOnly?) -> String? {
        guard let startDate, let endDate else { return nil }
        return String(
            format: teamLocalized("team.batchUpload.periodValue"),
            locale: AppLocalization.locale,
            startDate.rawValue,
            endDate.rawValue
        )
    }
}

private extension Color {
    var teamHexRGB: String {
        let uiColor = UIColor(self)
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 0
        guard uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else {
            return "#3B82F6"
        }
        return String(
            format: "#%02X%02X%02X",
            Int(round(red * 255)),
            Int(round(green * 255)),
            Int(round(blue * 255))
        )
    }
}
