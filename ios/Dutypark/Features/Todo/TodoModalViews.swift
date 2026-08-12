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

/// Web-style, content-fitting Todo detail panel presented inside `DPModalOverlay`.
struct TodoDetailModal: View {
    @ObservedObject var model: TodoViewModel
    let todo: TodoDTO
    let maximumHeight: CGFloat
    let onTodoChanged: () async -> Void
    let dismiss: () -> Void

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLeaveConfirmation = false
    @State private var headerHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var bodyContentHeight: CGFloat = 0
    @StateObject private var gallery: AttachmentGalleryModel

    init(
        model: TodoViewModel,
        todo: TodoDTO,
        maximumHeight: CGFloat,
        onTodoChanged: @escaping () async -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.todo = todo
        self.maximumHeight = maximumHeight
        self.onTodoChanged = onTodoChanged
        self.dismiss = dismiss
        _gallery = StateObject(
            wrappedValue: AttachmentGalleryModel(contextType: .todo, contextId: todo.id)
        )
    }

    private var maximumPanelHeight: CGFloat {
        maximumHeight * TodoModalLayout.maximumPanelHeightRatio
    }

    private var measuredBodyHeight: CGFloat {
        TodoModalLayout.bodyHeight(
            contentHeight: bodyContentHeight,
            maximumPanelHeight: maximumPanelHeight,
            fixedChromeHeight: headerHeight + footerHeight + DPChrome.borderWidth * 2
        )
    }

    var body: some View {
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
        .frame(maxHeight: maximumPanelHeight, alignment: .top)
        .background(DPColor.backgroundModal)
        .onPreferenceChange(TodoModalHeaderHeightPreferenceKey.self) { headerHeight = $0 }
        .onPreferenceChange(TodoModalBodyHeightPreferenceKey.self) { bodyContentHeight = $0 }
        .onPreferenceChange(TodoModalFooterHeightPreferenceKey.self) { footerHeight = $0 }
        .sheet(isPresented: $showingEdit) {
            TodoFormSheet(
                titleKey: "todo.form.editTitle",
                initialDraft: TodoDraft(todo: todo),
                friends: model.friends,
                model: model,
                targetTodoID: todo.id,
                existingAttachments: model.attachmentsByTodoID[todo.uuid, default: []],
                isSaving: model.isSaving
            ) { draft in
                let updated = await model.update(todo: todo, draft: draft)
                if updated {
                    await onTodoChanged()
                    dismiss()
                }
                return updated
            }
        }
        .confirmationDialog(
            todoLocalized("todo.confirm.deleteTitle"),
            isPresented: $showingDeleteConfirmation
        ) {
            Button(todoLocalized("todo.action.delete"), role: .destructive) {
                Task {
                    if await model.delete(todo) {
                        await onTodoChanged()
                        dismiss()
                    }
                }
            }
            Button(todoLocalized("common.cancel"), role: .cancel) {}
        } message: {
            Text(todoLocalized("todo.confirm.deleteMessage"))
        }
        .confirmationDialog(
            todoLocalized("todo.confirm.leaveTitle"),
            isPresented: $showingLeaveConfirmation
        ) {
            Button(todoLocalized("todo.action.leaveTag"), role: .destructive) {
                Task {
                    if await model.leaveTag(todo) {
                        await onTodoChanged()
                        dismiss()
                    }
                }
            }
            Button(todoLocalized("common.cancel"), role: .cancel) {}
        } message: {
            Text(todoLocalized("todo.confirm.leaveMessage"))
        }
        .todoModalErrorAlert(model)
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
        HStack(spacing: DPSpacing.small) {
            if todo.isTagged {
                TodoModalBorderedAction(
                    title: todoLocalized("todo.action.leaveTag"),
                    systemImage: "xmark",
                    color: DPColor.warning,
                    action: { showingLeaveConfirmation = true }
                )
            } else {
                TodoModalBorderedAction(
                    title: todoLocalized("common.edit"),
                    systemImage: "pencil",
                    color: DPColor.accent,
                    action: { showingEdit = true }
                )
                .disabled(todo.hasAttachments && model.attachmentsByTodoID[todo.uuid] == nil)

                TodoModalBorderedAction(
                    title: todoLocalized("todo.action.delete"),
                    systemImage: "trash",
                    color: DPColor.danger,
                    action: { showingDeleteConfirmation = true }
                )
            }

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
                .background(todo.status == .done ? DPColor.accent : DPColor.success)
                .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
            .buttonStyle(.plain)
            .disabled(model.isSaving)
        }
        .padding(DPSpacing.compact)
        .background(DPColor.backgroundModal)
    }
}

private struct TodoModalBorderedAction: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
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
