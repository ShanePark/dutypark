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

enum TodoDestructiveConfirmation: Equatable {
    case delete
    case leaveTag

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

struct TodoDestructiveConfirmationModal: View {
    let confirmation: TodoDestructiveConfirmation
    let isWorking: Bool
    let cancel: () -> Void
    let confirm: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Text(todoLocalized(confirmation.titleKey))
                .font(DPTypography.bodyMedium)
                .foregroundStyle(DPColor.textPrimary)
                .frame(maxWidth: .infinity, minHeight: 56)
                .padding(.horizontal, DPSpacing.large)
                .background(DPColor.backgroundTertiary)

            Text(todoLocalized(confirmation.messageKey))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(DPSpacing.large)
                .frame(maxWidth: .infinity)

            HStack(spacing: DPSpacing.compact) {
                Button(action: confirm) {
                    Group {
                        if isWorking {
                            ProgressView().tint(DPColor.textOnDark)
                        } else {
                            Text(todoLocalized(confirmation.actionKey))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(DPDestructiveButtonStyle())
                .disabled(isWorking)
                .accessibilityIdentifier("todo.confirm.confirm")

                Button(todoLocalized("common.cancel"), action: cancel)
                    .buttonStyle(DPOutlineButtonStyle())
                    .frame(maxWidth: .infinity)
                    .disabled(isWorking)
                    .accessibilityIdentifier("todo.confirm.cancel")
            }
            .padding(.horizontal, DPSpacing.large)
            .padding(.bottom, DPSpacing.large)
        }
        .frame(maxWidth: .infinity)
    }
}

struct TodoHelpModal: View {
    let maximumHeight: CGFloat
    let dismiss: () -> Void

    private let sections: [(String, String, String, Color)] = [
        ("square.grid.2x2", "todo.help.kanban.title", "todo.help.kanban.body", DPColor.accent),
        ("list.bullet", "todo.help.todo.title", "todo.help.todo.body", DPColor.accent),
        ("clock", "todo.help.progress.title", "todo.help.progress.body", DPColor.warning),
        ("checkmark.circle", "todo.help.done.title", "todo.help.done.body", DPColor.success)
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(todoLocalized("todo.help.title"))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todoLocalized("common.close"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.small)
            .padding(.vertical, DPSpacing.small)
            .background(DPColor.backgroundTertiary)

            ScrollView {
                VStack(alignment: .leading, spacing: DPSpacing.large) {
                    ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                        helpSection(icon: section.0, titleKey: section.1, bodyKey: section.2, color: section.3)
                    }

                    VStack(alignment: .leading, spacing: DPSpacing.small) {
                        Label(todoLocalized("todo.help.tips.title"), systemImage: "lightbulb")
                            .font(DPTypography.bodyMedium)
                            .foregroundStyle(DPColor.warning)
                        ForEach(1...5, id: \.self) { index in
                            HStack(alignment: .firstTextBaseline, spacing: DPSpacing.small) {
                                Text("•")
                                Text(todoLocalized("todo.help.tip.\(index)"))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            .font(DPTypography.supporting)
                            .foregroundStyle(DPColor.textSecondary)
                        }
                    }
                }
                .padding(DPSpacing.medium)
            }
            .scrollBounceBehavior(.basedOnSize)
        }
        .frame(maxHeight: min(maximumHeight * TodoModalLayout.maximumPanelHeightRatio, 720))
        .background(DPColor.backgroundModal)
    }

    private func helpSection(icon: String, titleKey: String, bodyKey: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Label(todoLocalized(titleKey), systemImage: icon)
                .font(DPTypography.bodyMedium)
                .foregroundStyle(color)
            Text(todoLocalized(bodyKey))
                .font(DPTypography.supporting)
                .foregroundStyle(DPColor.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// Web-style, content-fitting Todo detail panel presented inside `DPModalOverlay`.
struct TodoDetailModal: View {
    @ObservedObject var model: TodoViewModel
    let todo: TodoDTO
    let maximumHeight: CGFloat
    let onTodoChanged: () async -> Void
    let onDismissabilityChange: (Bool) -> Void
    let dismiss: () -> Void

    @State private var showingEdit = false
    @State private var confirmation: TodoDestructiveConfirmation?
    @State private var isConfirming = false
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var bodyContentHeight: CGFloat = 0
    @State private var isLoadingEditAttachments = false
    @StateObject private var gallery: AttachmentGalleryModel

    init(
        model: TodoViewModel,
        todo: TodoDTO,
        maximumHeight: CGFloat,
        onTodoChanged: @escaping () async -> Void,
        onDismissabilityChange: @escaping (Bool) -> Void = { _ in },
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.todo = todo
        self.maximumHeight = maximumHeight
        self.onTodoChanged = onTodoChanged
        self.onDismissabilityChange = onDismissabilityChange
        self.dismiss = dismiss
        _gallery = StateObject(
            wrappedValue: AttachmentGalleryModel(contextType: .todo, contextId: todo.id)
        )
    }

    private var maximumPanelHeight: CGFloat {
        min(maximumHeight, 874) * TodoModalLayout.maximumPanelHeightRatio
    }

    private var measuredBodyHeight: CGFloat {
        TodoModalLayout.bodyHeight(
            contentHeight: bodyContentHeight,
            maximumPanelHeight: maximumPanelHeight,
            fixedChromeHeight: headerHeight + footerHeight + DPChrome.borderWidth * 2
        )
    }

    var body: some View {
        Group {
            if showingEdit {
                TodoFormSheet(
                    titleKey: "todo.form.editTitle",
                    initialDraft: TodoDraft(todo: todo),
                    friends: model.friends,
                    model: model,
                    targetTodoID: todo.id,
                    existingAttachments: model.attachmentsByTodoID[todo.uuid, default: []],
                    isSaving: model.isSaving,
                    maximumHeight: maximumHeight,
                    dismissAction: { showingEdit = false },
                    savedDismissAction: dismiss,
                    onBusyChange: { onDismissabilityChange(!$0) }
                ) { draft in
                    let updated = await model.update(todo: todo, draft: draft)
                    if updated { await onTodoChanged() }
                    return updated
                }
            } else if let confirmation {
                TodoDestructiveConfirmationModal(
                    confirmation: confirmation,
                    isWorking: isConfirming || model.isSaving,
                    cancel: { self.confirmation = nil },
                    confirm: performConfirmation
                )
            } else {
                detailContent
            }
        }
        .frame(maxHeight: maximumPanelHeight, alignment: .top)
        .task(id: todo.uuid) {
            guard todo.hasAttachments, model.attachmentsByTodoID[todo.uuid] == nil else { return }
            isLoadingEditAttachments = true
            await model.loadAttachments(for: todo)
            isLoadingEditAttachments = false
        }
        .onChange(of: model.isSaving) { _, isSaving in
            onDismissabilityChange(!isSaving && !isConfirming)
        }
        .onDisappear { onDismissabilityChange(true) }
        .todoModalErrorAlert(model)
    }

    private var detailContent: some View {
        VStack(spacing: 0) {
            header
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TodoModalHeaderHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                }

            Divider().overlay(DPColor.borderPrimary)

            ScrollView {
                detailBody
                    .background {
                        GeometryReader { proxy in
                            Color.clear.preference(
                                key: TodoModalBodyHeightPreferenceKey.self,
                                value: proxy.size.height
                            )
                        }
                    }
            }
            .scrollBounceBehavior(.basedOnSize)
            .frame(height: measuredBodyHeight)

            Divider().overlay(DPColor.borderPrimary)

            footer
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TodoModalFooterHeightPreferenceKey.self,
                            value: proxy.size.height
                        )
                    }
                }
        }
        .background(DPColor.backgroundModal)
        .onPreferenceChange(TodoModalHeaderHeightPreferenceKey.self) { headerHeight = $0 }
        .onPreferenceChange(TodoModalBodyHeightPreferenceKey.self) { bodyContentHeight = $0 }
        .onPreferenceChange(TodoModalFooterHeightPreferenceKey.self) { footerHeight = $0 }
    }

    private func performConfirmation() {
        guard !isConfirming, let confirmation else { return }
        isConfirming = true
        onDismissabilityChange(false)
        Task {
            let succeeded: Bool
            switch confirmation {
            case .delete:
                succeeded = await model.delete(todo)
            case .leaveTag:
                succeeded = await model.leaveTag(todo)
            }
            isConfirming = false
            onDismissabilityChange(true)
            if succeeded {
                await onTodoChanged()
                await Task.yield()
                dismiss()
            }
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

                    Text(todoLocalized(todo.status.titleKey))
                        .foregroundStyle(todo.status.color)
                        .padding(.horizontal, DPSpacing.small)
                        .padding(.vertical, 4)
                        .background(todo.status.softColor, in: Capsule())
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
        .background(DPColor.backgroundModal)
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
                    TodoModalMemberChips(names: todo.isTagged ? [todo.owner] : todo.tags.map(\.name))
                }
            }

            if !todo.content.isEmpty {
                Text(todo.content)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .textSelection(.enabled)
            }

            if todo.hasAttachments {
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
        ViewThatFits(in: .horizontal) {
            HStack(spacing: DPSpacing.small) {
                secondaryActions
                primaryAction
            }

            VStack(spacing: DPSpacing.small) {
                primaryAction
                HStack(spacing: DPSpacing.small) {
                    secondaryActions
                }
            }
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundModal)
    }

    @ViewBuilder
    private var secondaryActions: some View {
        if todo.isTagged {
            TodoModalBorderedAction(
                title: todoLocalized("todo.action.leaveTag"),
                systemImage: "xmark",
                color: DPColor.warning,
                action: { confirmation = .leaveTag }
            )
        } else {
            TodoModalBorderedAction(
                title: todoLocalized("common.edit"),
                systemImage: "pencil",
                color: DPColor.accent,
                isLoading: isLoadingEditAttachments,
                action: { showingEdit = true }
            )
            .disabled(todo.hasAttachments && model.attachmentsByTodoID[todo.uuid] == nil)

            TodoModalBorderedAction(
                title: todoLocalized("todo.action.delete"),
                systemImage: "trash",
                color: DPColor.danger,
                action: { confirmation = .delete }
            )
        }
    }

    private var primaryAction: some View {
        Button {
            Task {
                let succeeded = todo.status == .done
                    ? await model.reopen(todo)
                    : await model.complete(todo)
                if succeeded {
                    await onTodoChanged()
                    dismiss()
                }
            }
        } label: {
            Label(
                todoLocalized(todo.status == .done ? "todo.action.reopen" : "todo.action.complete"),
                systemImage: todo.status == .done ? "arrow.uturn.backward" : "checkmark"
            )
            .font(DPTypography.label)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .foregroundStyle(DPColor.textOnDark)
            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            .padding(.horizontal, DPSpacing.small)
            .background(todo.status == .done ? DPColor.accent : DPColor.success)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
        }
        .buttonStyle(.plain)
        .disabled(model.isSaving)
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
                .frame(minHeight: DPSize.minimumTouchTarget)
                .background(DPColor.backgroundCard)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                .overlay(
                    RoundedRectangle(cornerRadius: DPRadius.standard)
                        .stroke(color.opacity(0.55), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
    }
}

private struct TodoModalMemberChips: View {
    let names: [String]

    var body: some View {
        TodoModalFlowLayout(spacing: DPSpacing.small) {
            ForEach(Array(names.enumerated()), id: \.offset) { _, name in
                Label(name, systemImage: "person.fill")
                    .font(DPTypography.caption)
                    .foregroundStyle(DPColor.textSecondary)
                    .padding(.horizontal, 9)
                    .padding(.vertical, 5)
                    .background(DPColor.backgroundTertiary, in: Capsule())
            }
        }
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

private struct TodoModalHeaderHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TodoModalBodyHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

private struct TodoModalFooterHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
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
