import SwiftUI

enum TodoModalLayout {
    static let maximumPanelHeightRatio: CGFloat = 0.9
    static let minimumBodyHeight: CGFloat = 1

    static func bodyHeight(
        contentHeight: CGFloat,
        maximumPanelHeight: CGFloat,
        fixedChromeHeight: CGFloat
    ) -> CGFloat {
        let availableHeight = max(minimumBodyHeight, maximumPanelHeight - fixedChromeHeight)
        return min(max(contentHeight, minimumBodyHeight), availableHeight)
    }
}

enum TodoDestructiveConfirmation: Equatable, Identifiable {
    case delete
    case leaveTag

    var id: String {
        switch self {
        case .delete: "delete"
        case .leaveTag: "leaveTag"
        }
    }

    var titleKey: String {
        switch self {
        case .delete: "todo.confirm.deleteTitle"
        case .leaveTag: "todo.confirm.leaveTitle"
        }
    }

    var messageKey: String {
        switch self {
        case .delete: "todo.confirm.deleteMessage"
        case .leaveTag: "todo.confirm.leaveMessage"
        }
    }

    var actionKey: String {
        switch self {
        case .delete: "todo.action.delete"
        case .leaveTag: "todo.action.leaveTag"
        }
    }
}

nonisolated enum TodoConfirmationPolicy {
    static func canBegin(isConfirming: Bool, isSaving: Bool) -> Bool {
        !isConfirming && !isSaving
    }

    static func canDismiss(isConfirming: Bool, isSaving: Bool) -> Bool {
        !isConfirming && !isSaving
    }
}

struct TodoHelpModal: View {
    let maximumHeight: CGFloat
    let dismiss: () -> Void

    private let sections: [(icon: String, titleKey: String, bodyKey: String, tint: Color)] = [
        ("square.grid.2x2", "todo.help.kanban.title", "todo.help.kanban.body", DPColor.accent),
        ("list.bullet", "todo.help.todo.title", "todo.help.todo.body", DPColor.accent),
        ("clock", "todo.help.progress.title", "todo.help.progress.body", DPColor.warning),
        ("checkmark.circle", "todo.help.done.title", "todo.help.done.body", DPColor.success)
    ]

    private static let tipCount = 5

    var body: some View {
        DPHelpModal(
            title: todoLocalized("todo.help.title"),
            closeLabel: todoLocalized("common.close"),
            maximumHeight: maximumHeight,
            dismiss: dismiss
        ) {
            // The blocks describe the board and its three columns rather than steps to
            // follow in order, so they stay unnumbered.
            ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                DPHelpSection(
                    systemImage: section.icon,
                    title: todoLocalized(section.titleKey),
                    message: todoLocalized(section.bodyKey),
                    tint: section.tint
                )
            }

            DPHelpNote(
                systemImage: "lightbulb",
                title: todoLocalized("todo.help.tips.title"),
                tint: DPColor.warning,
                messages: (1...Self.tipCount).map { todoLocalized("todo.help.tip.\($0)") }
            )
        }
    }
}

/// Web-style, content-fitting Todo detail panel presented inside `DPModalOverlay`.
struct TodoDetailModal: View {
    @ObservedObject var model: TodoViewModel
    let todo: TodoDTO
    let maximumHeight: CGFloat
    let accountID: MemberID?
    let sessionGeneration: UInt64?
    let onTodoChanged: () async -> Void
    let onDismissabilityChange: (Bool) -> Void
    let dismissRequest: Int
    let dismiss: () -> Void

    @State private var showingEdit = false
    @State private var confirmation: TodoDestructiveConfirmation?
    @State private var isConfirming = false
    @State private var dismissDetailAfterConfirmation = false
    @State private var deferredConfirmationErrorKey: String?
    @State private var isLoadingEditAttachments = false
    @State private var reportTarget: ReportTarget?
    @State private var reportCanDismiss = true
    @State private var dismissesAfterReportedBlock = false
    @State private var isChangingStatus = false
    @StateObject private var gallery: AttachmentGalleryModel

    init(
        model: TodoViewModel,
        todo: TodoDTO,
        maximumHeight: CGFloat,
        accountID: MemberID? = nil,
        sessionGeneration: UInt64? = nil,
        onTodoChanged: @escaping () async -> Void,
        onDismissabilityChange: @escaping (Bool) -> Void = { _ in },
        dismissRequest: Int = 0,
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.todo = todo
        self.maximumHeight = maximumHeight
        self.accountID = accountID
        self.sessionGeneration = sessionGeneration
        self.onTodoChanged = onTodoChanged
        self.onDismissabilityChange = onDismissabilityChange
        self.dismissRequest = dismissRequest
        self.dismiss = dismiss
        _gallery = StateObject(
            wrappedValue: AttachmentGalleryModel(contextType: .todo, contextId: todo.id)
        )
    }

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * TodoModalLayout.maximumPanelHeightRatio
    }

    var body: some View {
        Group {
            if showingEdit {
                TodoFormSheet(
                    titleKey: "todo.form.editTitle",
                    initialDraft: TodoDraft(todo: currentTodo),
                    friends: model.friends,
                    model: model,
                    targetTodoID: todo.id,
                    existingAttachments: model.attachmentsByTodoID[currentTodo.uuid, default: []],
                    preservedTags: currentTodo.tags,
                    accountID: accountID,
                    sessionGeneration: sessionGeneration,
                    isSaving: model.isSaving,
                    maximumHeight: maximumHeight,
                    dismissAction: {
                        model.emitHaptic(.routine)
                        showingEdit = false
                    },
                    savedDismissAction: dismiss,
                    dismissRequest: dismissRequest,
                    onBusyChange: { onDismissabilityChange(!$0) }
                ) { draft in
                    let updated = await model.update(todo: currentTodo, draft: draft)
                    if updated { await onTodoChanged() }
                    return updated
                }
            } else {
                detailContent
            }
        }
        .task(id: todo.uuid) {
            guard todo.hasAttachments, model.attachmentsByTodoID[todo.uuid] == nil else { return }
            isLoadingEditAttachments = true
            await model.loadAttachments(for: todo)
            isLoadingEditAttachments = false
        }
        .onChange(of: model.isSaving) { _, isSaving in
            onDismissabilityChange(!isSaving && !isConfirming)
        }
        .onChange(of: dismissRequest) { _, _ in
            if !showingEdit, confirmation == nil, !isConfirming, !model.isSaving {
                dismiss()
            }
        }
        .onDisappear {
            guard confirmation == nil else { return }
            onDismissabilityChange(true)
        }
        .fullScreenCover(item: $reportTarget) { target in
            DPModalOverlay(
                onDismiss: { finishReportDismissal() },
                canDismiss: reportCanDismiss
            ) { availableSize, dismissReport in
                ReportSheet(
                    target: target,
                    maximumHeight: availableSize.height,
                    onDismissabilityChange: { reportCanDismiss = $0 },
                    onBlocked: { dismissesAfterReportedBlock = true },
                    dismiss: dismissReport
                )
            }
        }
        .fullScreenCover(item: $confirmation) { requestedConfirmation in
            DPModalOverlay(
                maximumContentWidth: DPConfirmationPanel.maximumWidth,
                onDismiss: { finishConfirmationDismissal() },
                canDismiss: TodoConfirmationPolicy.canDismiss(
                    isConfirming: isConfirming,
                    isSaving: model.isSaving
                ),
                // The confirmation buttons already provide their press feedback;
                // do not add a second tick when the panel itself closes.
                dismissHaptic: nil
            ) { availableSize, confirmationDismiss in
                DPConfirmationPanel(
                    title: todoLocalized(requestedConfirmation.titleKey),
                    message: todoLocalized(requestedConfirmation.messageKey),
                    confirmTitle: todoLocalized(requestedConfirmation.actionKey),
                    cancelTitle: todoLocalized("common.cancel"),
                    isDestructive: true,
                    isWorking: isConfirming || model.isSaving,
                    maximumHeight: availableSize.height,
                    cancel: confirmationDismiss,
                    confirm: {
                        performConfirmation(
                            requestedConfirmation,
                            dismissConfirmation: confirmationDismiss
                        )
                    }
                )
            }
        }
    }

    private var detailContent: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            header
        } content: {
            detailBody
        } footer: {
            footer
        }
        .accessibilityIdentifier("todo.detail")
        .todoModalErrorAlert(model)
    }

    private func performConfirmation(
        _ requestedConfirmation: TodoDestructiveConfirmation,
        dismissConfirmation: @escaping () -> Void
    ) {
        guard confirmation == requestedConfirmation,
              TodoConfirmationPolicy.canBegin(
                  isConfirming: isConfirming,
                  isSaving: model.isSaving
              ) else { return }
        isConfirming = true
        onDismissabilityChange(false)
        Task {
            let succeeded: Bool
            switch requestedConfirmation {
            case .delete:
                succeeded = await model.delete(todo)
            case .leaveTag:
                succeeded = await model.leaveTag(todo)
            }
            isConfirming = false
            if succeeded {
                await onTodoChanged()
                dismissDetailAfterConfirmation = true
            } else {
                deferredConfirmationErrorKey = model.errorKey
                model.errorKey = nil
                onDismissabilityChange(true)
            }
            await Task.yield()
            dismissConfirmation()
        }
    }

    private func finishConfirmationDismissal() {
        confirmation = nil
        if dismissDetailAfterConfirmation {
            dismissDetailAfterConfirmation = false
            onDismissabilityChange(true)
            Task {
                await Task.yield()
                dismiss()
            }
        } else if let deferredConfirmationErrorKey {
            self.deferredConfirmationErrorKey = nil
            Task {
                await Task.yield()
                model.errorKey = deferredConfirmationErrorKey
            }
        }
    }

    private func finishReportDismissal() {
        reportTarget = nil
        reportCanDismiss = true
        guard dismissesAfterReportedBlock else { return }
        dismissesAfterReportedBlock = false
        Task {
            await Task.yield()
            dismiss()
            await model.refresh()
            await onTodoChanged()
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: DPSpacing.small) {
            VStack(alignment: .leading, spacing: 6) {
                Text(todo.title)
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)

                HStack(spacing: DPSpacing.small) {
                    Label(
                        todo.createdDate.rawValue.replacingOccurrences(of: "T", with: " "),
                        systemImage: "clock"
                    )
                    .lineLimit(1)
                }
                .font(DPTypography.caption)
                .foregroundStyle(DPColor.textMuted)
            }

            Spacer(minLength: 0)

            Button(action: dismiss) {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(todoLocalized("common.close"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.compact)
    }

    private var currentTodo: TodoDTO {
        for status in TodoStatus.boardStatuses {
            if let currentTodo = model.todos(for: status).first(where: { $0.uuid == todo.uuid }) {
                return currentTodo
            }
        }
        return todo
    }

    private var currentStatus: TodoStatus {
        currentTodo.status
    }

    private var statusAction: some View {
        Menu {
            ForEach(TodoStatus.boardStatuses, id: \.rawValue) { destination in
                Button {
                    changeStatus(to: destination)
                } label: {
                    Label(
                        todoLocalized(destination.titleKey),
                        systemImage: destination.systemImage
                    )
                }
                .disabled(destination == currentStatus || statusChangeIsBlocked)
            }
        } label: {
            TodoModalFooterActionLabel(
                title: todoLocalized("todo.action.status"),
                systemImage: "arrow.left.arrow.right",
                color: currentStatus.color,
                isLoading: isChangingStatus
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(todoLocalized("todo.action.status"))
        .accessibilityValue(todoLocalized(currentStatus.titleKey))
        .accessibilityIdentifier("todo.detail.status")
        .disabled(statusChangeIsBlocked)
    }

    private var statusChangeIsBlocked: Bool {
        isChangingStatus || model.isSaving || !model.canPerformOnlineMutations
    }

    private func changeStatus(to destination: TodoStatus) {
        guard !isChangingStatus,
              !model.isSaving,
              currentStatus != destination
        else { return }
        isChangingStatus = true
        Task {
            let succeeded = await model.move(currentTodo, to: destination)
            if succeeded {
                await onTodoChanged()
            }
            isChangingStatus = false
        }
    }

    private var detailBody: some View {
        VStack(alignment: .leading, spacing: DPSpacing.medium) {
            if let dueDate = todo.dueDate {
                Label {
                    Text(todoLocalized("todo.field.dueDate") + ": " + dueDate.rawValue)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(DPTypography.supporting)
                .foregroundStyle(todo.isOverdue ? DPColor.danger : DPColor.textSecondary)
            }

            if todo.isTagged || !todo.tags.isEmpty {
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    Text(todoLocalized(todo.isTagged ? "todo.field.owner" : "todo.field.tags"))
                        .font(DPFont.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(DPColor.textMuted)
                    TodoModalFlowLayout(spacing: DPSpacing.small) {
                        ForEach(TodoMemberTagAdapter.items(of: todo)) { item in
                            DPMemberTagChip(item: item, size: .regular)
                        }
                    }
                }
            }

            if !todo.content.isEmpty {
                Text(todo.content)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            // `AttachmentGallery` performs its own remote list request in its
            // task. Cached Calendar details are read-only offline, so do not
            // mount the gallery until the model is bound to an online session.
            if todo.hasAttachments, model.canPerformOnlineMutations {
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    Text(todoLocalized("todo.label.attachments"))
                        .font(DPFont.bold(size: 12, relativeTo: .caption))
                        .foregroundStyle(DPColor.textMuted)
                    AttachmentGallery(model: gallery)
                }
            }
        }
        .padding(DPSpacing.medium)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var footer: some View {
        HStack(spacing: DPSpacing.small) {
            statusAction
            secondaryActions
        }
        .padding(DPSpacing.compact)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if currentTodo.isTagged {
            TodoModalBorderedAction(
                title: todoLocalized("todo.action.leaveTag"),
                systemImage: "xmark",
                color: DPColor.danger,
                action: { confirmation = .leaveTag }
            )
            .accessibilityIdentifier("todo.detail.leaveTag")
            .disabled(statusChangeIsBlocked)

            reportMenu
        } else {
            TodoModalBorderedAction(
                title: todoLocalized("common.edit"),
                systemImage: "pencil",
                color: DPColor.accent,
                isLoading: isLoadingEditAttachments,
                action: {
                    model.emitHaptic(.routine)
                    showingEdit = true
                }
            )
            .disabled(
                statusChangeIsBlocked
                    || (currentTodo.hasAttachments && model.attachmentsByTodoID[currentTodo.uuid] == nil)
            )

            TodoModalBorderedAction(
                title: todoLocalized("todo.action.delete"),
                systemImage: "trash",
                color: DPColor.danger,
                action: { confirmation = .delete }
            )
            .disabled(statusChangeIsBlocked)
        }
    }

    /// Reporting remains available for tagged Todos, while tag removal stays a
    /// primary footer action instead of being hidden behind this menu.
    private var reportMenu: some View {
        Menu {
            Button(role: .destructive) {
                withoutPresentationAnimation {
                    reportTarget = ReportTarget(
                        type: .todo,
                        targetID: currentTodo.id,
                        name: currentTodo.title
                    )
                }
            } label: {
                Label {
                    Text(todoLocalized("todo.action.report"))
                } icon: {
                    DPReportBeaconIcon()
                }
            }
            .accessibilityIdentifier("todo.detail.report")
        } label: {
            Image(systemName: "ellipsis")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(DPColor.textSecondary)
                .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                .contentShape(Rectangle())
        }
        .accessibilityLabel(todoLocalized("todo.action.more"))
        .accessibilityIdentifier("todo.detail.menu")
        .disabled(statusChangeIsBlocked)
    }

}

private struct TodoModalFooterActionLabel: View {
    @Environment(\.isEnabled) private var isEnabled

    let title: String
    let systemImage: String
    let color: Color
    let isLoading: Bool

    var body: some View {
        Group {
            if isLoading {
                HStack(spacing: DPSpacing.extraSmall) {
                    ProgressView()
                        .controlSize(.small)
                    Text(title)
                }
            } else {
                Label(title, systemImage: systemImage)
            }
        }
        .font(DPTypography.label)
        .lineLimit(1)
        .minimumScaleFactor(0.75)
        .foregroundStyle(color)
        .padding(.horizontal, DPSpacing.small)
        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay(
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(color.opacity(0.55), lineWidth: 1)
        )
        .opacity(isEnabled ? 1 : DPChrome.disabledOpacity)
    }
}

private struct TodoModalBorderedAction: View {
    let title: String
    let systemImage: String
    let color: Color
    var isLoading = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            TodoModalFooterActionLabel(
                title: title,
                systemImage: systemImage,
                color: color,
                isLoading: isLoading
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TodoModalFlowLayout: Layout {
    let spacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        layout(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let result = layout(proposal: proposal, subviews: subviews)
        for (index, point) in result.points.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y),
                proposal: .unspecified
            )
        }
    }

    private func layout(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> (size: CGSize, points: [CGPoint]) {
        let availableWidth = proposal.width ?? .infinity
        var points: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var lineHeight: CGFloat = 0
        var usedWidth: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > availableWidth {
                x = 0
                y += lineHeight + spacing
                lineHeight = 0
            }
            points.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            lineHeight = max(lineHeight, size.height)
            usedWidth = max(usedWidth, x - spacing)
        }

        return (
            CGSize(width: min(usedWidth, availableWidth), height: y + lineHeight),
            points
        )
    }
}

private struct TodoModalErrorAlertModifier: ViewModifier {
    @ObservedObject var model: TodoViewModel

    func body(content: Content) -> some View {
        content.alert(
            todoLocalized("todo.error.title"),
            isPresented: Binding(
                get: { model.errorKey != nil },
                set: { if !$0 { model.errorKey = nil } }
            )
        ) {
            Button(todoLocalized("common.ok"), role: .cancel) {
                model.errorKey = nil
            }
        } message: {
            if let errorKey = model.errorKey {
                Text(todoLocalized(errorKey))
            }
        }
    }
}

private extension View {
    func todoModalErrorAlert(_ model: TodoViewModel) -> some View {
        modifier(TodoModalErrorAlertModifier(model: model))
    }
}
