import SwiftUI
import UniformTypeIdentifiers

struct TeamManageView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismissView
    @StateObject private var viewModel: TeamManageViewModel
    @State private var pendingAction: PendingAction?

    init(teamID: TeamID) {
        _viewModel = StateObject(wrappedValue: TeamManageViewModel(teamID: teamID))
    }

    private var loginID: MemberID? {
        if case .authenticated(let member) = session.state { member.id } else { nil }
    }

    var body: some View {
        VStack(spacing: 0) {
            manageHeader(viewModel.team)
            Group {
                if viewModel.isLoading && viewModel.team == nil {
                    DPLoadingState(label: LocalizedStringKey(teamLocalized("team.common.loading")))
                } else if let team = viewModel.team {
                ScrollView {
                    VStack(spacing: DPSpacing.medium) {
                        informationSection(team)
                        membersSection(team)
                        dutyTypesSection(team)
                    }
                    .padding(.horizontal, DPSpacing.small)
                    .padding(.vertical, DPSpacing.medium)
                }
                .background(DPColor.backgroundPrimary)
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
        }
        .navigationBarBackButtonHidden(true)
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

    private func manageHeader(_ team: TeamDTO?) -> some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                dismissView()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .background(DPColor.surfaceStrongAlt)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            .buttonStyle(.plain)
            .accessibilityLabel(Text("team.manage.actions.back", tableName: "Team"))
            Text(
                String(
                    format: teamLocalized("team.manage.title"),
                    locale: AppLocalization.locale,
                    team?.name ?? ""
                )
            )
            .font(DPTypography.sectionTitle)
            .lineLimit(2)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            Color.clear.frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
        }
        .foregroundStyle(DPColor.textOnDark)
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.surfaceStrong)
        .clipShape(UnevenRoundedRectangle(topLeadingRadius: DPRadius.standard, topTrailingRadius: DPRadius.standard))
        .padding(.horizontal, DPSpacing.small)
        .padding(.top, DPSpacing.medium)
    }

    private func informationSection(_ team: TeamDTO) -> some View {
        VStack(spacing: 0) {
            manageInfoRow(
                label: teamLocalized("team.manage.fields.description"),
                value: team.description ?? teamLocalized("team.manage.labels.notAvailable")
            )
            if viewModel.canUseAdminTools(loginID: loginID) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("team.manage.fields.admin", tableName: "Team")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                    HStack {
                        Text(verbatim: team.adminName ?? teamLocalized("team.manage.labels.notAvailable"))
                            .font(DPTypography.label)
                    if team.adminId != nil, team.adminId != loginID {
                        Button(role: .destructive) {
                            pendingAction = .changeAdmin(nil)
                        } label: {
                            Label(teamLocalized("team.manage.actions.resetAdmin"), systemImage: "trash")
                                .font(DPTypography.caption)
                                .frame(minHeight: DPSize.minimumTouchTarget)
                        }
                    }
                    }
                }
                .padding(.horizontal, DPSpacing.medium)
                .padding(.vertical, DPSpacing.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(alignment: .top) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("team.manage.fields.batchTemplate", tableName: "Team")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
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
                .pickerStyle(.menu)
                .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget, alignment: .leading)
                .padding(.horizontal, DPSpacing.compact)
                .background(DPColor.backgroundInput)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay { RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderInput) }
            }
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.compact)
            .overlay(alignment: .top) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
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
                .buttonStyle(DPPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .padding(DPSpacing.medium)
                .overlay(alignment: .top) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: DPRadius.standard, bottomTrailingRadius: DPRadius.standard))
        .overlay { UnevenRoundedRectangle(bottomLeadingRadius: DPRadius.standard, bottomTrailingRadius: DPRadius.standard).stroke(DPColor.borderPrimary) }
        .padding(.top, -DPSpacing.medium)
    }

    private func membersSection(_ team: TeamDTO) -> some View {
        VStack(spacing: 0) {
            teamSectionHeader(
                title: teamLocalized("team.manage.fields.members"),
                buttonTitle: teamLocalized("team.manage.actions.addMember"),
                systemImage: "person.badge.plus"
            ) { viewModel.memberSearchPresented = true }
            if team.members.isEmpty {
                Text("team.manage.labels.noMembers", tableName: "Team")
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            ForEach(Array(team.members.enumerated()), id: \.offset) { index, member in
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    HStack {
                        Text(verbatim: String(index + 1)).font(DPTypography.label).foregroundStyle(DPColor.textMuted)
                        Text(verbatim: member.name).font(DPTypography.bodyMedium)
                        if member.isManager { Image(systemName: "checkmark").foregroundStyle(DPColor.success) }
                        Spacer()
                        if let id = member.id {
                            Button { pendingAction = .removeMember(id) } label: {
                                Label(teamLocalized("team.manage.actions.removeMember"), systemImage: "trash")
                                    .font(DPTypography.caption)
                            }
                            .buttonStyle(DPDestructiveButtonStyle())
                        }
                    }
                    if let id = member.id, viewModel.canUseAdminTools(loginID: loginID), !member.isAdmin {
                        HStack(spacing: DPSpacing.extraSmall) {
                            if member.isManager {
                                teamSmallAction(teamLocalized("team.manage.actions.revokeManager"), "shield.slash", DPColor.warning, DPColor.warningBorder) { pendingAction = .removeManager(id) }
                                teamSmallAction(teamLocalized("team.manage.actions.transferAdmin"), "crown", DPColor.accent, DPColor.accentBorder) { pendingAction = .changeAdmin(id) }
                            } else {
                                teamSmallAction(teamLocalized("team.manage.actions.assignManager"), "plus", DPColor.success, DPColor.successBorder) { pendingAction = .addManager(id) }
                            }
                        }
                    }
                }
                .padding(DPSpacing.compact)
                .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay { RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary) }
    }

    private func dutyTypesSection(_ team: TeamDTO) -> some View {
        VStack(spacing: 0) {
            teamSectionHeader(
                title: teamLocalized("team.manage.fields.dutyTypes"),
                buttonTitle: teamLocalized("team.manage.actions.addDutyType"),
                systemImage: "plus",
                secondary: true
            ) {
                viewModel.editingDutyType = nil
                viewModel.dutyEditorPresented = true
            }
            if team.dutyTypes.isEmpty {
                Text("team.manage.labels.noDutyTypes", tableName: "Team")
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, minHeight: 72)
            }
            ScrollView(.horizontal) {
                VStack(spacing: 0) {
                    HStack(spacing: 0) {
                        teamTableHeader("#", width: 44)
                        teamTableHeader(teamLocalized("team.manage.fields.dutyName"), width: 104)
                        teamTableHeader(teamLocalized("team.manage.fields.color"), width: 64)
                        teamTableHeader(teamLocalized("team.manage.fields.status"), width: 84)
                        teamTableHeader(teamLocalized("team.manage.fields.tools"), width: 190)
                    }
                    ForEach(Array(team.dutyTypes.enumerated()), id: \.offset) { index, dutyType in
                        HStack(spacing: 0) {
                            teamTableCell(String(index + 1), width: 44)
                            teamTableCell(dutyType.name, width: 104)
                            Circle().fill(Color(teamHex: dutyType.color)).frame(width: 24, height: 24).frame(width: 64).frame(minHeight: 60)
                            Text(dutyType.hidden ? "team.manage.labels.hidden" : dutyType.id == nil ? "team.manage.labels.offDuty" : "team.manage.labels.visible", tableName: "Team")
                                .font(DPTypography.caption)
                                .foregroundStyle(dutyType.hidden ? DPColor.textMuted : DPColor.success)
                                .padding(.horizontal, DPSpacing.small).padding(.vertical, DPSpacing.extraSmall)
                                .background(dutyType.hidden ? DPColor.backgroundTertiary : DPColor.successSoft)
                                .clipShape(Capsule()).frame(width: 84)
                            HStack(spacing: DPSpacing.extraSmall) {
                                if dutyType.id != nil {
                                    teamToolButton(
                                        "arrow.down",
                                        label: teamLocalized("team.dutyType.actions.saveOrder"),
                                        isDisabled: TeamFeatureLogic.visibleDutyTypeNeighbor(in: team.dutyTypes, from: index, direction: 1) == nil
                                    ) { Task { await viewModel.moveDutyType(from: index, direction: 1) } }
                                    teamToolButton(
                                        "arrow.up",
                                        label: teamLocalized("team.dutyType.actions.saveOrder"),
                                        isDisabled: TeamFeatureLogic.visibleDutyTypeNeighbor(in: team.dutyTypes, from: index, direction: -1) == nil
                                    ) { Task { await viewModel.moveDutyType(from: index, direction: -1) } }
                                }
                                teamToolButton("pencil", label: teamLocalized("team.dutyType.actions.edit"), tint: DPColor.accent) {
                            viewModel.editingDutyType = dutyType
                            viewModel.dutyEditorPresented = true
                                }
                                if dutyType.id != nil {
                                    teamToolButton(
                                        dutyType.hidden ? "eye" : "eye.slash",
                                        label: dutyType.hidden ? teamLocalized("team.manage.actions.restoreDutyType") : teamLocalized("team.manage.actions.hideDutyType"),
                                        tint: dutyType.hidden ? DPColor.success : DPColor.warning
                                    ) { Task { await viewModel.toggleVisibility(dutyType) } }
                                }
                            }
                            .frame(width: 190)
                        }
                        .opacity(dutyType.hidden ? 0.6 : 1)
                        .overlay(alignment: .bottom) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
                    }
                }
            }
        }
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay { RoundedRectangle(cornerRadius: DPRadius.standard).stroke(DPColor.borderPrimary) }
    }

    private func manageInfoRow(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: label).font(DPTypography.caption).foregroundStyle(DPColor.textMuted)
            Text(verbatim: value).font(DPTypography.label).foregroundStyle(DPColor.textPrimary)
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.compact)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func teamSectionHeader(
        title: String,
        buttonTitle: String,
        systemImage: String,
        secondary: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        HStack {
            Text(verbatim: title).font(DPTypography.bodyMedium)
            Spacer()
            Button(action: action) {
                Label(buttonTitle, systemImage: systemImage)
                    .font(DPTypography.label)
                    .padding(.horizontal, DPSpacing.compact)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .background(secondary ? DPColor.backgroundCard : DPColor.accent)
                    .foregroundStyle(secondary ? DPColor.textPrimary : DPColor.textOnDark)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            .buttonStyle(.plain)
        }
        .foregroundStyle(DPColor.textOnDark)
        .padding(.horizontal, DPSpacing.medium)
        .padding(.vertical, DPSpacing.small)
        .background(DPColor.surfaceStrong)
    }

    private func teamSmallAction(
        _ title: String,
        _ systemImage: String,
        _ tint: Color,
        _ border: Color,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(DPTypography.caption)
                .foregroundStyle(tint)
                .padding(.horizontal, DPSpacing.small)
                .frame(minHeight: DPSize.minimumTouchTarget)
                .overlay { RoundedRectangle(cornerRadius: DPRadius.small).stroke(border) }
        }
        .buttonStyle(.plain)
    }

    private func teamTableHeader(_ title: String, width: CGFloat) -> some View {
        Text(verbatim: title)
            .font(DPTypography.label)
            .foregroundStyle(DPColor.textOnDark)
            .frame(width: width)
            .frame(minHeight: 40)
            .background(DPColor.backgroundFooter)
    }

    private func teamTableCell(_ title: String, width: CGFloat) -> some View {
        Text(verbatim: title)
            .font(DPTypography.label)
            .foregroundStyle(DPColor.textPrimary)
            .lineLimit(2)
            .frame(width: width)
            .frame(minHeight: 60)
    }

    private func teamToolButton(
        _ systemImage: String,
        label: String,
        tint: Color = DPColor.textPrimary,
        isDisabled: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                .overlay { RoundedRectangle(cornerRadius: DPRadius.small).stroke(DPColor.borderSecondary) }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? DPChrome.disabledOpacity : 1)
        .accessibilityLabel(Text(verbatim: label))
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
            VStack(spacing: 0) {
                HStack {
                    Text(viewModel.editingDutyType == nil ? "team.dutyType.titleAdd" : "team.dutyType.titleEdit", tableName: "Team")
                        .font(DPTypography.bodyMedium)
                    Spacer()
                    Button { dismiss() } label: {
                        Image(systemName: "xmark").frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    }.buttonStyle(.plain)
                }
                .padding(.horizontal, DPSpacing.medium).padding(.vertical, DPSpacing.small)
                .background(DPColor.backgroundTertiary)
                VStack(alignment: .leading, spacing: DPSpacing.medium) {
                    TextField(teamLocalized("team.dutyType.placeholders.name"), text: $name)
                        .dpInputChrome(isInvalid: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    ColorPicker(teamLocalized("team.manage.fields.color"), selection: $color, supportsOpacity: false)
                        .frame(minHeight: DPSize.minimumTouchTarget)
                }
                .padding(DPSpacing.medium)
                Spacer(minLength: 0)
                HStack(spacing: DPSpacing.small) {
                    Button(teamLocalized("team.common.save")) {
                        Task {
                            await viewModel.saveDutyType(name: name, color: color.teamHexRGB)
                            if !viewModel.showsError { dismiss() }
                        }
                    }
                    .buttonStyle(DPSuccessButtonStyle())
                    .disabled(name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    Button(teamLocalized("team.common.cancel")) { dismiss() }
                        .buttonStyle(DPSecondaryButtonStyle())
                }
                .padding(DPSpacing.medium)
                .overlay(alignment: .top) { Rectangle().fill(DPColor.borderPrimary).frame(height: 1) }
            }
            .background(DPColor.backgroundModal)
            .navigationBarHidden(true)
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
