import SwiftUI
import UniformTypeIdentifiers

struct TeamManageView: View {
    @EnvironmentObject private var session: SessionStore
    @Environment(\.dismiss) private var dismissView
    @StateObject private var viewModel: TeamManageViewModel
    @State private var pendingAction: PendingAction?
    @State private var pendingActionIsWorking = false
    @State private var memberSearchIsWorking = false
    @State private var dutyEditorInteraction = TeamModalInteractionState()
    @State private var batchUploadInteraction = TeamModalInteractionState()
    private let onTeamChanged: (TeamDTO) -> Void
    private let onDutyBatchChanged: (Int, Int) -> Void

    init(
        teamID: TeamID,
        onTeamChanged: @escaping (TeamDTO) -> Void = { _ in },
        onDutyBatchChanged: @escaping (Int, Int) -> Void = { _, _ in }
    ) {
        _viewModel = StateObject(
            wrappedValue: TeamManageViewModel(
                teamID: teamID
            )
        )
        self.onTeamChanged = onTeamChanged
        self.onDutyBatchChanged = onDutyBatchChanged
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
        .dpInteractivePopGestureEnabled()
        .task { await viewModel.load() }
        .onChange(of: viewModel.team) { _, team in
            if let team { onTeamChanged(team) }
        }
        .fullScreenCover(isPresented: $viewModel.memberSearchPresented) {
            DPModalOverlay(
                onDismiss: { viewModel.memberSearchPresented = false },
                closeOnBackdrop: true,
                canDismiss: !memberSearchIsWorking
            ) { availableSize, dismiss in
                TeamMemberSearchView(
                    teamID: viewModel.teamID,
                    maximumHeight: availableSize.height,
                    isWorking: $memberSearchIsWorking,
                    dismissAfterSuccess: { viewModel.memberSearchPresented = false },
                    didAdd: { viewModel.appendMember($0) },
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.dutyEditorPresented) {
            DPModalOverlay(
                onDismiss: { viewModel.dutyEditorPresented = false },
                closeOnBackdrop: true,
                canDismiss: !dutyEditorInteraction.isWorking,
                onDismissRequest: { _ in dutyEditorInteraction.dismissRequestSerial += 1 }
            ) { availableSize, dismiss in
                TeamDutyTypeEditor(
                    viewModel: viewModel,
                    maximumHeight: availableSize.height,
                    interaction: $dutyEditorInteraction,
                    dismissAfterSuccess: { viewModel.dutyEditorPresented = false },
                    dismiss: dismiss
                )
            }
        }
        .fullScreenCover(isPresented: $viewModel.batchUploadPresented) {
            DPModalOverlay(
                onDismiss: { viewModel.batchUploadPresented = false },
                closeOnBackdrop: true,
                canDismiss: !batchUploadInteraction.isWorking,
                onDismissRequest: { _ in batchUploadInteraction.dismissRequestSerial += 1 }
            ) { availableSize, dismiss in
                TeamBatchUploadView(
                    viewModel: viewModel,
                    maximumHeight: availableSize.height,
                    interaction: $batchUploadInteraction,
                    didUpload: onDutyBatchChanged,
                    dismiss: dismiss
                )
            }
        }
        .alert(
            Text("team.common.error", tableName: "Team"),
            isPresented: Binding(
                get: { viewModel.showsError && pendingAction == nil },
                set: { if !$0 { viewModel.showsError = false } }
            )
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        } message: {
            Text(viewModel.errorMessage ?? teamLocalized("team.common.error"))
        }
        .alert(
            Text("team.manage.messages.updateSuccess", tableName: "Team"),
            isPresented: Binding(
                get: { viewModel.showsSuccess && pendingAction == nil },
                set: { if !$0 { viewModel.showsSuccess = false } }
            )
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        }
        .fullScreenCover(
            isPresented: Binding(
                get: { pendingAction != nil },
                set: {
                    if !$0, !viewModel.isWorking, !pendingActionIsWorking {
                        pendingAction = nil
                    }
                }
            )
        ) {
            if let action = pendingAction {
                DPModalOverlay(
                    maximumContentWidth: DPConfirmationPanel.maximumWidth,
                    onDismiss: {
                        guard !viewModel.isWorking, !pendingActionIsWorking else { return }
                        pendingAction = nil
                    },
                    closeOnBackdrop: true,
                    canDismiss: !viewModel.isWorking && !pendingActionIsWorking,
                    dismissHaptic: nil
                ) { availableSize, dismiss in
                    TeamAsyncConfirmationPanel(
                        title: confirmationTitle(for: action),
                        message: confirmationMessage(for: action),
                        confirmTitle: confirmationButtonTitle(for: action),
                        isDestructive: action.isDestructive,
                        isWorking: viewModel.isWorking,
                        maximumHeight: availableSize.height,
                        dismiss: dismiss,
                        dismissAfterSuccess: {
                            pendingAction = nil
                        },
                        workingChanged: { pendingActionIsWorking = $0 }
                    ) {
                        await run(action)
                    }
                    .alert(
                        Text("team.common.error", tableName: "Team"),
                        isPresented: $viewModel.showsError
                    ) {
                        Button(teamLocalized("team.common.confirm"), role: .cancel) {}
                    } message: {
                        Text(viewModel.errorMessage ?? teamLocalized("team.common.error"))
                    }
                }
                .interactiveDismissDisabled(viewModel.isWorking || pendingActionIsWorking)
            }
        }
    }

    private func manageHeader(_ team: TeamDTO?) -> some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                dismissView()
                DPHapticCenter.shared.emit(.routine)
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
            Color.clear
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                .accessibilityHidden(true)
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
                            present(.changeAdmin(nil))
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
                        set: { name in
                            let currentName = team.dutyBatchTemplate?.name ?? ""
                            guard name != currentName else { return }
                            DPHapticCenter.shared.emit(.selection)
                            Task { await viewModel.updateTemplate(name.isEmpty ? nil : name) }
                        }
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
                    batchUploadInteraction = TeamModalInteractionState()
                    withoutPresentationAnimation { viewModel.batchUploadPresented = true }
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
            ) {
                memberSearchIsWorking = false
                DPHapticCenter.shared.emit(.routine)
                withoutPresentationAnimation { viewModel.memberSearchPresented = true }
            }
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
                            Button { present(.removeMember(id)) } label: {
                                Label(teamLocalized("team.manage.actions.removeMember"), systemImage: "trash")
                                    .font(DPTypography.caption)
                            }
                            .buttonStyle(DPDestructiveButtonStyle())
                        }
                    }
                    if let id = member.id, viewModel.canUseAdminTools(loginID: loginID), !member.isAdmin {
                        HStack(spacing: DPSpacing.extraSmall) {
                            if member.isManager {
                                teamSmallAction(teamLocalized("team.manage.actions.revokeManager"), "shield.slash", DPColor.warning, DPColor.warningBorder) { present(.removeManager(id)) }
                                teamSmallAction(teamLocalized("team.manage.actions.transferAdmin"), "crown", DPColor.accent, DPColor.accentBorder) { present(.changeAdmin(id)) }
                            } else {
                                teamSmallAction(teamLocalized("team.manage.actions.assignManager"), "plus", DPColor.success, DPColor.successBorder) { present(.addManager(id)) }
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
                dutyEditorInteraction = TeamModalInteractionState()
                DPHapticCenter.shared.emit(.routine)
                withoutPresentationAnimation { viewModel.dutyEditorPresented = true }
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
                            dutyEditorInteraction = TeamModalInteractionState()
                            DPHapticCenter.shared.emit(.routine)
                            withoutPresentationAnimation { viewModel.dutyEditorPresented = true }
                                }
                                if dutyType.id != nil {
                                    teamToolButton(
                                        dutyType.hidden ? "eye" : "eye.slash",
                                        label: dutyType.hidden ? teamLocalized("team.manage.actions.restoreDutyType") : teamLocalized("team.manage.actions.hideDutyType"),
                                        tint: dutyType.hidden ? DPColor.success : DPColor.warning
                                    ) { present(.setDutyTypeVisibility(dutyType)) }
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

    private func present(_ action: PendingAction) {
        pendingActionIsWorking = false
        if !action.isDestructive {
            DPHapticCenter.shared.emit(.routine)
        }
        withoutPresentationAnimation { pendingAction = action }
    }

    private func confirmationTitle(for action: PendingAction) -> String {
        switch action {
        case .removeMember: teamLocalized("team.manage.actions.removeMember")
        case .addManager: teamLocalized("team.manage.actions.assignManager")
        case .removeManager: teamLocalized("team.manage.actions.revokeManager")
        case .changeAdmin(let id):
            id == nil
                ? teamLocalized("team.manage.actions.resetAdmin")
                : teamLocalized("team.manage.actions.transferAdmin")
        case .setDutyTypeVisibility(let dutyType):
            dutyType.hidden
                ? teamLocalized("team.manage.actions.restoreDutyType")
                : teamLocalized("team.manage.actions.hideDutyType")
        }
    }

    private func confirmationButtonTitle(for action: PendingAction) -> String {
        confirmationTitle(for: action)
    }

    private func confirmationMessage(for action: PendingAction) -> String {
        let key: String
        let memberID: MemberID?
        switch action {
        case .removeMember(let id):
            key = "team.manage.messages.removeMemberConfirm"
            memberID = id
        case .addManager(let id):
            key = "team.manage.messages.assignManagerConfirm"
            memberID = id
        case .removeManager(let id):
            key = "team.manage.messages.unassignManagerConfirm"
            memberID = id
        case .changeAdmin(let id):
            guard let id else {
                let team = viewModel.team
                let name = TeamManageConfirmationCopy.currentAdminName(
                    adminName: team?.adminName,
                    adminID: team?.adminId,
                    members: team?.members ?? [],
                    fallback: teamLocalized("team.manage.labels.notAvailable")
                )
                return TeamManageConfirmationCopy.resetAdminMessage(name: name)
            }
            key = "team.manage.messages.changeAdminConfirm"
            memberID = id
        case .setDutyTypeVisibility(let dutyType):
            key = dutyType.hidden
                ? "team.dutyType.messages.restoreConfirm"
                : "team.dutyType.messages.hideConfirm"
            return String(
                format: teamLocalized(key),
                locale: AppLocalization.locale,
                dutyType.name
            )
        }
        let name = viewModel.team?.members.first(where: { $0.id == memberID })?.name
            ?? teamLocalized("team.manage.labels.notAvailable")
        return String(format: teamLocalized(key), locale: AppLocalization.locale, name, name)
    }

    private func run(_ action: PendingAction?) async -> Bool {
        switch action {
        case .removeMember(let id): return await viewModel.removeMember(id)
        case .addManager(let id): return await viewModel.addManager(id)
        case .removeManager(let id): return await viewModel.removeManager(id)
        case .changeAdmin(let id): return await viewModel.changeAdmin(memberID: id)
        case .setDutyTypeVisibility(let dutyType): return await viewModel.toggleVisibility(dutyType)
        case nil: return false
        }
    }

    private enum PendingAction: Equatable {
        case removeMember(MemberID)
        case addManager(MemberID)
        case removeManager(MemberID)
        case changeAdmin(MemberID?)
        case setDutyTypeVisibility(DutyTypeDTO)

        var isDestructive: Bool {
            switch self {
            case .removeMember, .removeManager, .changeAdmin(nil): true
            case .setDutyTypeVisibility(let dutyType): !dutyType.hidden
            case .addManager, .changeAdmin: false
            }
        }
    }
}

nonisolated enum TeamManageConfirmationCopy {
    static func currentAdminName(
        adminName: String?,
        adminID: MemberID?,
        members: [TeamMemberDTO],
        fallback: String
    ) -> String {
        if let adminName = nonempty(adminName) {
            return adminName
        }
        if let adminID,
           let memberName = nonempty(members.first(where: { $0.id == adminID })?.name) {
            return memberName
        }
        return fallback
    }

    static func resetAdminMessage(name: String, locale: Locale? = nil) -> String {
        AppLocalization.format(
            "team.manage.messages.resetAdminConfirm",
            table: "Team",
            arguments: [name],
            locale: locale
        )
    }

    private static func nonempty(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines),
              !trimmed.isEmpty
        else { return nil }
        return trimmed
    }
}

private extension View {
    /// Every team management modal asks the same question before throwing away
    /// unsaved edits, so the copy and the wiring live in one place.
    func teamDiscardConfirmation(
        isPresented: Binding<Bool>,
        discard: @escaping () -> Void
    ) -> some View {
        dpConfirmation(
            isPresented: isPresented,
            copy: DPConfirmationCopy(
                title: teamLocalized("team.modal.discard.title"),
                message: teamLocalized("team.modal.discard.message"),
                confirmTitle: teamLocalized("team.modal.discard.action"),
                cancelTitle: teamLocalized("team.modal.discard.continue"),
                isDestructive: true
            ),
            confirm: { _ in discard() }
        )
    }
}

private struct TeamDutyTypeEditor: View {
    @ObservedObject var viewModel: TeamManageViewModel
    let maximumHeight: CGFloat
    @Binding var interaction: TeamModalInteractionState
    let dismissAfterSuccess: () -> Void
    let dismiss: () -> Void
    @State private var name = ""
    @State private var color = Color.blue
    @State private var isSubmitting = false
    @State private var initialName = ""
    @State private var initialColorHex = Color.blue.teamHexRGB
    @State private var showsDiscardConfirmation = false
    @FocusState private var focusedField: Field?

    private enum Field { case name }

    private var trimmedName: String {
        TeamManageModalLogic.normalizedDutyName(name)
    }

    private var hasDuplicateName: Bool {
        TeamManageModalLogic.hasDuplicateDutyName(
            trimmedName,
            editingID: viewModel.editingDutyType?.id,
            editingDefaultDuty: viewModel.editingDutyType != nil && viewModel.editingDutyType?.id == nil,
            dutyTypes: viewModel.team?.dutyTypes ?? []
        )
    }

    private var canSave: Bool {
        !trimmedName.isEmpty && !hasDuplicateName && !isSubmitting && !viewModel.isWorking
    }

    var body: some View {
        DPModalPanel(
            maximumPanelHeight: min(maximumHeight * 0.64, 500),
            scrollTarget: focusedField
        ) {
            teamModalHeader(
                title: teamLocalized(
                    viewModel.editingDutyType == nil
                        ? "team.dutyType.titleAdd"
                        : "team.dutyType.titleEdit"
                ),
                isWorking: isSubmitting || viewModel.isWorking,
                dismiss: requestDismiss
            )
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                Text("team.dutyType.description", tableName: "Team")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)

                if viewModel.editingDutyType != nil, viewModel.editingDutyType?.id == nil {
                    HStack(alignment: .top, spacing: DPSpacing.small) {
                        Image(systemName: "info.circle.fill")
                        Text(
                            teamLocalized("team.dutyType.defaultNoticeStart")
                                + teamLocalized("team.dutyType.defaultNoticeStrong")
                                + teamLocalized("team.dutyType.defaultNoticeEnd")
                        )
                    }
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.accent)
                    .padding(DPSpacing.compact)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(DPColor.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.standard)
                            .stroke(DPColor.accentBorder)
                    }
                }

                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    HStack {
                        Text("team.dutyType.fields.name", tableName: "Team")
                            .font(DPTypography.label)
                        Spacer()
                        Text(verbatim: "\(name.count)/\(TeamManageModalLogic.maximumDutyNameLength)")
                            .font(DPTypography.caption)
                            .foregroundStyle(
                                name.count == TeamManageModalLogic.maximumDutyNameLength
                                    ? DPColor.warning
                                    : DPColor.textMuted
                            )
                    }
                    TextField(teamLocalized("team.dutyType.placeholders.name"), text: $name)
                        .focused($focusedField, equals: .name)
                        .dpInputChrome(isInvalid: name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .onChange(of: name) { _, newValue in
                            name = String(newValue.prefix(TeamManageModalLogic.maximumDutyNameLength))
                        }
                    if hasDuplicateName {
                        Text(
                            String(
                                format: teamLocalized("team.dutyType.warnings.duplicate"),
                                locale: AppLocalization.locale,
                                trimmedName
                            )
                        )
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.danger)
                    }
                }
                .id(Field.name)

                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text("team.dutyType.fields.color", tableName: "Team")
                        .font(DPTypography.label)
                    ColorPicker(
                        teamLocalized("team.dutyType.fields.color"),
                        selection: $color,
                        supportsOpacity: false
                    )
                    .labelsHidden()
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget, alignment: .leading)
                }

                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text("team.dutyType.fields.preview", tableName: "Team")
                        .font(DPTypography.label)
                    Text(
                        verbatim: trimmedName.isEmpty
                            ? teamLocalized("team.dutyType.placeholders.preview")
                            : trimmedName
                    )
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
                    .padding(.horizontal, DPSpacing.medium)
                    .frame(minHeight: DPSize.minimumTouchTarget)
                    .background(color.opacity(0.78))
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .overlay {
                        RoundedRectangle(cornerRadius: DPRadius.standard)
                            .stroke(DPColor.borderPrimary)
                    }
                }
            }
            .padding(DPSpacing.medium)
        } footer: {
            HStack(spacing: DPSpacing.small) {
                Button {
                    requestDismiss()
                } label: {
                    Text(verbatim: teamLocalized("team.common.close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(isSubmitting || viewModel.isWorking)
                Button {
                    guard canSave else { return }
                    isSubmitting = true
                    Task {
                        await viewModel.saveDutyType(name: trimmedName, color: color.teamHexRGB)
                        isSubmitting = false
                        updateInteractionState()
                        if !viewModel.showsError { dismissAfterSuccess() }
                    }
                } label: {
                    Text(verbatim: teamLocalized("team.common.save"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSuccessButtonStyle())
                .disabled(!canSave)
            }
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundFooter)
        }
        .onAppear {
            if let dutyType = viewModel.editingDutyType {
                name = dutyType.name
                color = Color(teamHex: dutyType.color)
            }
            initialName = name
            initialColorHex = color.teamHexRGB
            updateInteractionState()
        }
        .onChange(of: name) { _, _ in updateInteractionState() }
        .onChange(of: color) { oldValue, newValue in
            if oldValue != newValue {
                DPHapticCenter.shared.emit(.selection)
            }
            updateInteractionState()
        }
        .onChange(of: isSubmitting) { _, _ in updateInteractionState() }
        .onChange(of: viewModel.isWorking) { _, _ in updateInteractionState() }
        .onChange(of: interaction.dismissRequestSerial) { _, _ in requestDismiss() }
        .teamDiscardConfirmation(isPresented: $showsDiscardConfirmation) {
            showsDiscardConfirmation = false
            dismiss()
        }
    }

    private func updateInteractionState() {
        interaction.isDirty = name != initialName || color.teamHexRGB != initialColorHex
        interaction.isWorking = isSubmitting || viewModel.isWorking
    }

    private func requestDismiss() {
        switch interaction.dismissDecision {
        case .blocked:
            return
        case .confirmDiscard:
            showsDiscardConfirmation = true
        case .dismiss:
            dismiss()
        }
    }
}

private struct TeamMemberSearchView: View {
    @StateObject private var viewModel: TeamMemberSearchViewModel
    let maximumHeight: CGFloat
    @Binding var isWorking: Bool
    let dismissAfterSuccess: () -> Void
    let didAdd: (MemberInviteCandidateDTO) -> Void
    let dismiss: () -> Void
    @State private var candidateToAdd: MemberInviteCandidateDTO?
    @State private var candidateSubmissionIsWorking = false
    @State private var didLoadInitialResults = false
    @FocusState private var focusedField: Field?

    private enum Field { case keyword }

    init(
        teamID: TeamID,
        maximumHeight: CGFloat,
        isWorking: Binding<Bool>,
        dismissAfterSuccess: @escaping () -> Void,
        didAdd: @escaping (MemberInviteCandidateDTO) -> Void,
        dismiss: @escaping () -> Void
    ) {
        _viewModel = StateObject(wrappedValue: TeamMemberSearchViewModel(teamID: teamID))
        self.maximumHeight = maximumHeight
        _isWorking = isWorking
        self.dismissAfterSuccess = dismissAfterSuccess
        self.didAdd = didAdd
        self.dismiss = dismiss
    }

    var body: some View {
        searchPanel
        .fullScreenCover(
            isPresented: Binding(
                get: { candidateToAdd != nil },
                set: {
                    if !$0, !viewModel.isWorking, !candidateSubmissionIsWorking {
                        candidateToAdd = nil
                    }
                }
            )
        ) {
            if let candidate = candidateToAdd {
                DPModalOverlay(
                    maximumContentWidth: DPConfirmationPanel.maximumWidth,
                    onDismiss: {
                        guard !viewModel.isWorking, !candidateSubmissionIsWorking else { return }
                        candidateToAdd = nil
                    },
                    canDismiss: !viewModel.isWorking && !candidateSubmissionIsWorking,
                    dismissHaptic: nil
                ) { availableSize, confirmationDismiss in
                    TeamAsyncConfirmationPanel(
                        title: teamLocalized("team.memberSearch.add"),
                        message: String(
                            format: teamLocalized("team.memberSearch.confirmAdd"),
                            locale: AppLocalization.locale,
                            candidate.name
                        ),
                        confirmTitle: teamLocalized("team.memberSearch.add"),
                        isDestructive: false,
                        isWorking: viewModel.isWorking,
                        maximumHeight: availableSize.height,
                        dismiss: confirmationDismiss,
                        dismissAfterSuccess: {
                            didAdd(candidate)
                            candidateToAdd = nil
                            dismissAfterSuccess()
                        },
                        workingChanged: {
                            candidateSubmissionIsWorking = $0
                            isWorking = $0
                        }
                    ) {
                        await viewModel.add(candidate)
                    }
                }
                .interactiveDismissDisabled(viewModel.isWorking || candidateSubmissionIsWorking)
            }
        }
        .task {
            guard !didLoadInitialResults else { return }
            didLoadInitialResults = true
            await viewModel.search(resetPage: true)
        }
        .onAppear { isWorking = viewModel.isWorking }
        .onChange(of: viewModel.isWorking) { _, value in isWorking = value }
        .alert(
            Text("team.common.error", tableName: "Team"),
            isPresented: $viewModel.showsError
        ) {
            Button(teamLocalized("team.common.confirm"), role: .cancel) {}
        }
    }

    private var searchPanel: some View {
        DPModalPanel(maximumPanelHeight: maximumHeight, scrollTarget: focusedField) {
            teamModalHeader(
                title: teamLocalized("team.memberSearch.title"),
                isWorking: viewModel.isWorking,
                dismiss: dismiss
            )
        } content: {
            VStack(spacing: DPSpacing.compact) {
                HStack(spacing: DPSpacing.small) {
                    TextField(
                        teamLocalized("team.memberSearch.searchPlaceholder"),
                        text: $viewModel.keyword
                    )
                    .textInputAutocapitalization(.never)
                    .submitLabel(.search)
                    .focused($focusedField, equals: .keyword)
                    .dpInputChrome()
                    .onSubmit { Task { await viewModel.search(resetPage: true) } }

                    Button {
                        Task { await viewModel.search(resetPage: true) }
                    } label: {
                        Image(systemName: "magnifyingglass")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DPColor.textOnDark)
                    .background(DPColor.surfaceStrong)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    .accessibilityLabel(Text("team.memberSearch.searchPlaceholder", tableName: "Team"))
                }
                .id(Field.keyword)

                VStack(spacing: DPSpacing.small) {
                    ForEach(Array(viewModel.results.enumerated()), id: \.offset) { index, member in
                        memberRow(member, index: index)
                    }
                }
                .padding(.vertical, DPSpacing.extraSmall)
                .frame(maxWidth: .infinity, minHeight: 150)
                .overlay {
                    if viewModel.isWorking {
                        ProgressView()
                    } else if viewModel.results.isEmpty {
                        ContentUnavailableView(
                            teamLocalized("team.memberSearch.empty"),
                            systemImage: "person.crop.circle.badge.questionmark"
                        )
                    }
                }

                if !viewModel.results.isEmpty {
                    Text(
                        String(
                            format: teamLocalized("team.memberSearch.pagination"),
                            locale: AppLocalization.locale,
                            Int64(viewModel.currentPage + 1),
                            Int64(viewModel.totalPages),
                            viewModel.totalElements
                        )
                    )
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .leading)

                    HStack {
                        Button {
                            Task { await viewModel.previousPage() }
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        }
                        .disabled(!viewModel.canLoadPreviousPage)
                        Spacer()
                        Text(verbatim: "\(viewModel.currentPage + 1) / \(viewModel.totalPages)")
                            .font(DPTypography.label)
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
            .padding(DPSpacing.medium)
        } footer: {
            HStack(spacing: DPSpacing.small) {
                Button {
                    dismiss()
                } label: {
                    Text(verbatim: teamLocalized("team.common.close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(viewModel.isWorking)
            }
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundFooter)
        }
    }

    private func memberRow(_ member: MemberInviteCandidateDTO, index: Int) -> some View {
        HStack(spacing: DPSpacing.small) {
            Text(verbatim: String(viewModel.currentPage * 5 + index + 1))
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: member.name)
                    .font(DPTypography.bodyMedium)
                    .foregroundStyle(DPColor.textPrimary)
                    .lineLimit(1)
                Text(verbatim: member.email ?? teamLocalized("team.manage.labels.notAvailable"))
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textMuted)
                    .lineLimit(1)
            }
            Spacer(minLength: DPSpacing.extraSmall)
            Button(member.teamId == nil
                ? teamLocalized("team.memberSearch.add")
                : teamLocalized("team.memberSearch.alreadyAssigned")) {
                DPHapticCenter.shared.emit(.routine)
                withoutPresentationAnimation { candidateToAdd = member }
            }
            .buttonStyle(.plain)
            .font(DPTypography.caption)
            .foregroundStyle(member.teamId == nil ? DPColor.textOnDark : DPColor.textMuted)
            .padding(.horizontal, DPSpacing.small)
            .background(member.teamId == nil ? DPColor.accent : DPColor.backgroundTertiary)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .overlay {
                RoundedRectangle(cornerRadius: DPRadius.standard)
                    .stroke(member.teamId == nil ? DPColor.accentBorder : DPColor.borderSecondary)
            }
            .controlSize(.small)
            .frame(minHeight: DPSize.minimumTouchTarget)
            .disabled(member.teamId != nil || viewModel.isWorking)
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundSecondary)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        }
    }

}

private struct TeamBatchUploadView: View {
    @ObservedObject var viewModel: TeamManageViewModel
    let maximumHeight: CGFloat
    @Binding var interaction: TeamModalInteractionState
    let didUpload: (Int, Int) -> Void
    let dismiss: () -> Void
    @State private var year = Calendar.current.component(.year, from: Date())
    @State private var month = Calendar.current.component(.month, from: Date())
    @State private var fileURL: URL?
    @State private var fileImporterPresented = false
    @State private var result: TeamBatchResultDTO?
    @State private var initialYear = Calendar.current.component(.year, from: Date())
    @State private var initialMonth = Calendar.current.component(.month, from: Date())
    @State private var initialFileURL: URL?
    @State private var showsDiscardConfirmation = false

    private let currentYear = Calendar.current.component(.year, from: Date())

    var body: some View {
        DPModalPanel(maximumPanelHeight: min(maximumHeight * 0.66, 560)) {
            teamModalHeader(
                title: teamLocalized("team.batchUpload.title"),
                isWorking: viewModel.isWorking,
                dismiss: requestDismiss
            )
        } content: {
            VStack(alignment: .leading, spacing: DPSpacing.medium) {
                VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                    Text("team.batchUpload.fileLabel", tableName: "Team")
                        .font(DPTypography.label)
                    Button {
                        DPHapticCenter.shared.emit(.routine)
                        fileImporterPresented = true
                    } label: {
                        HStack {
                            Image(systemName: "doc.badge.plus")
                            Text(
                                verbatim: fileURL?.lastPathComponent
                                    ?? teamLocalized("team.batchUpload.selectFile")
                            )
                                .lineLimit(1)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(DPTypography.caption)
                        }
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                        .padding(.horizontal, DPSpacing.compact)
                        .background(DPColor.backgroundInput)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .overlay {
                            RoundedRectangle(cornerRadius: DPRadius.standard)
                                .stroke(DPColor.borderInput)
                        }
                    }
                    .buttonStyle(.plain)
                    .disabled(viewModel.isWorking)
                }

                HStack(spacing: DPSpacing.small) {
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        Text("team.batchUpload.year", tableName: "Team")
                            .font(DPTypography.label)
                        Picker(teamLocalized("team.batchUpload.year"), selection: $year) {
                            ForEach(currentYear...(currentYear + 1), id: \.self) { value in
                                Text(verbatim: String(value)).tag(value)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.backgroundInput)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .onChange(of: year) { oldValue, newValue in
                            if oldValue != newValue {
                                DPHapticCenter.shared.emit(.selection)
                            }
                            updateInteractionState()
                        }
                    }
                    VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                        Text("team.batchUpload.month", tableName: "Team")
                            .font(DPTypography.label)
                        Picker(teamLocalized("team.batchUpload.month"), selection: $month) {
                            ForEach(1...12, id: \.self) { Text(verbatim: String($0)).tag($0) }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                        .background(DPColor.backgroundInput)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                        .onChange(of: month) { oldValue, newValue in
                            if oldValue != newValue {
                                DPHapticCenter.shared.emit(.selection)
                            }
                            updateInteractionState()
                        }
                    }
                }

                if let result {
                    Text("team.batchUpload.result", tableName: "Team")
                        .font(DPTypography.bodyMedium)
                    if let period = batchPeriod(result.startDate, result.endDate) {
                        LabeledContent(teamLocalized("team.batchUpload.period"), value: period)
                            .font(DPTypography.caption)
                    }
                    if !result.result {
                        Text(verbatim: batchMessage(result.errorCode, result.errorDetails))
                            .foregroundStyle(DPColor.danger)
                    }
                    ForEach(Array(result.dutyBatchResult.enumerated()), id: \.offset) { _, item in
                        VStack(alignment: .leading, spacing: DPSpacing.extraSmall) {
                            HStack(alignment: .top) {
                                Text(verbatim: item.memberName).font(DPTypography.label)
                                Spacer()
                                Text(
                                    verbatim: item.result.result
                                        ? teamLocalized("team.batchUpload.success")
                                        : batchMessage(item.result.errorCode, item.result.errorDetails)
                                )
                                .font(DPTypography.caption)
                                .foregroundStyle(item.result.result ? DPColor.success : DPColor.danger)
                                .multilineTextAlignment(.trailing)
                            }
                            if let period = batchPeriod(item.result.startDate, item.result.endDate) {
                                Text(verbatim: period)
                                    .font(DPTypography.caption)
                                    .foregroundStyle(DPColor.textSecondary)
                            }
                        }
                        .padding(DPSpacing.compact)
                        .background(DPColor.backgroundSecondary)
                        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                    }
                }
            }
            .padding(DPSpacing.medium)
        } footer: {
            HStack(spacing: DPSpacing.small) {
                Button {
                    requestDismiss()
                } label: {
                    Text(verbatim: teamLocalized("team.common.close"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPSecondaryButtonStyle())
                .disabled(viewModel.isWorking)
                Button {
                    guard let fileURL,
                          TeamFeatureLogic.isValidDutyBatchYear(year, currentYear: currentYear)
                    else { return }
                    Task {
                        result = await viewModel.upload(fileURL: fileURL, year: year, month: month)
                        if result?.result == true {
                            didUpload(year, month)
                        }
                        initialYear = year
                        initialMonth = month
                        initialFileURL = fileURL
                        updateInteractionState()
                    }
                } label: {
                    Text(verbatim: teamLocalized("team.manage.actions.upload"))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .disabled(
                    fileURL == nil
                        || !TeamFeatureLogic.isValidDutyBatchYear(year, currentYear: currentYear)
                        || viewModel.isWorking
                )
            }
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundFooter)
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
        .onAppear { updateInteractionState() }
        .onChange(of: fileURL) { _, _ in updateInteractionState() }
        .onChange(of: viewModel.isWorking) { _, _ in updateInteractionState() }
        .onChange(of: interaction.dismissRequestSerial) { _, _ in requestDismiss() }
        .teamDiscardConfirmation(isPresented: $showsDiscardConfirmation) {
            showsDiscardConfirmation = false
            dismiss()
        }
    }

    private func updateInteractionState() {
        interaction.isDirty = year != initialYear || month != initialMonth || fileURL != initialFileURL
        interaction.isWorking = viewModel.isWorking
    }

    private func requestDismiss() {
        switch interaction.dismissDecision {
        case .blocked:
            return
        case .confirmDiscard:
            showsDiscardConfirmation = true
        case .dismiss:
            dismiss()
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

private struct TeamAsyncConfirmationPanel: View {
    let title: String
    let message: String
    let confirmTitle: String
    let isDestructive: Bool
    let isWorking: Bool
    let maximumHeight: CGFloat
    let dismiss: () -> Void
    let dismissAfterSuccess: () -> Void
    var workingChanged: ((Bool) -> Void)? = nil
    let confirm: () async -> Bool
    @State private var isSubmitting = false

    var body: some View {
        DPConfirmationPanel(
            title: title,
            message: message,
            confirmTitle: confirmTitle,
            cancelTitle: teamLocalized("team.common.cancel"),
            isDestructive: isDestructive,
            isWorking: isBusy,
            maximumHeight: maximumHeight,
            cancel: dismiss,
            confirm: submit
        )
        .onAppear { workingChanged?(isBusy) }
        .onChange(of: isWorking) { _, _ in workingChanged?(isBusy) }
        .onChange(of: isSubmitting) { _, _ in workingChanged?(isBusy) }
    }

    private var isBusy: Bool {
        isSubmitting || isWorking
    }

    private func submit() {
        guard TeamConfirmationSubmissionPolicy.canSubmit(
            isSubmitting: isSubmitting,
            isWorking: isWorking
        ) else { return }
        isSubmitting = true
        Task {
            let didSucceed = await confirm()
            isSubmitting = false
            if TeamManageModalLogic.shouldDismissConfirmation(didSucceed: didSucceed) {
                dismissAfterSuccess()
            }
        }
    }
}

@ViewBuilder
private func teamModalHeader(
    title: String,
    isWorking: Bool,
    dismiss: @escaping () -> Void
) -> some View {
    HStack(spacing: DPSpacing.small) {
        Text(verbatim: title)
            .font(DPTypography.heading)
            .foregroundStyle(DPColor.textPrimary)
            .lineLimit(2)
        Spacer(minLength: DPSpacing.small)
        if isWorking {
            ProgressView()
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
        } else {
            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 18, weight: .semibold))
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DPColor.textSecondary)
            .accessibilityLabel(Text("team.common.cancel", tableName: "Team"))
        }
    }
    .padding(.horizontal, DPSpacing.medium)
    .padding(.vertical, DPSpacing.small)
    .background(DPColor.backgroundTertiary)
}

nonisolated enum TeamModalDismissDecision: Equatable, Sendable {
    case dismiss
    case confirmDiscard
    case blocked
}

nonisolated struct TeamModalInteractionState: Equatable, Sendable {
    var isDirty = false
    var isWorking = false
    var dismissRequestSerial = 0

    var dismissDecision: TeamModalDismissDecision {
        if isWorking { return .blocked }
        return isDirty ? .confirmDiscard : .dismiss
    }
}

nonisolated enum TeamConfirmationSubmissionPolicy {
    static func canSubmit(isSubmitting: Bool, isWorking: Bool) -> Bool {
        !isSubmitting && !isWorking
    }
}

nonisolated enum TeamManageModalLogic {
    static let maximumDutyNameLength = 10

    static func limitedDutyName(_ value: String) -> String {
        String(value.prefix(maximumDutyNameLength))
    }

    static func normalizedDutyName(_ value: String) -> String {
        limitedDutyName(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func shouldDismissConfirmation(didSucceed: Bool) -> Bool {
        didSucceed
    }

    static func hasDuplicateDutyName(
        _ name: String,
        editingID: DutyTypeID?,
        editingDefaultDuty: Bool,
        dutyTypes: [DutyTypeDTO]
    ) -> Bool {
        guard !name.isEmpty else { return false }
        return dutyTypes.contains { dutyType in
            if editingDefaultDuty, dutyType.id == nil { return false }
            if let editingID, dutyType.id == editingID { return false }
            return dutyType.name.trimmingCharacters(in: .whitespacesAndNewlines) == name
        }
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
