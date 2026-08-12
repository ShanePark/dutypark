import SwiftUI

func todoLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Todo", locale: locale)
}

struct TodoView: View {
    let initialTodoID: TodoID?
    let onTodoChanged: () async -> Void
    let onInitialTodoOpened: () -> Void

    @StateObject private var model: TodoViewModel
    @State private var selectedTodo: TodoDTO?
    @State private var showingDetail = false
    @State private var showingCreate = false

    init(
        initialTodoID: TodoID? = nil,
        repository: any TodoRepository = TodoAPIRepository(),
        onTodoChanged: @escaping () async -> Void = {},
        onInitialTodoOpened: @escaping () -> Void = {}
    ) {
        self.initialTodoID = initialTodoID
        self.onTodoChanged = onTodoChanged
        self.onInitialTodoOpened = onInitialTodoOpened
        _model = StateObject(wrappedValue: TodoViewModel(repository: repository))
    }

    var body: some View {
        VStack(spacing: DPSpacing.small) {
            statusSelector
                .padding(.horizontal, DPSpacing.medium)

            content
        }
        .background(DPColor.backgroundSecondary)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingCreate = true
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityRepresentation {
                    Button {
                        showingCreate = true
                    } label: {
                        Color.clear
                            .frame(
                                width: DPSize.minimumTouchTarget + 2,
                                height: DPSize.minimumTouchTarget + 2
                            )
                            .contentShape(Rectangle())
                    }
                    .accessibilityLabel(todoLocalized("todo.action.add"))
                    .accessibilityIdentifier("todo.add")
                }
            }
        }
        .task(id: initialTodoID) {
            if model.board == nil {
                await model.load()
            } else {
                await model.refresh()
            }
            openInitialTodoIfPresent()
        }
        .sheet(isPresented: $showingCreate) {
            TodoFormSheet(
                titleKey: "todo.form.createTitle",
                initialDraft: TodoDraft(status: model.selectedStatus),
                friends: model.friends,
                model: model,
                targetTodoID: nil,
                existingAttachments: [],
                isSaving: model.isSaving
            ) { draft in
                let created = await model.create(draft: draft)
                if created { await onTodoChanged() }
                return created
            }
        }
        .sheet(isPresented: $showingDetail) {
            if let selectedTodo {
                TodoDetailSheet(model: model, todo: selectedTodo, onTodoChanged: onTodoChanged) {
                    showingDetail = false
                }
            }
        }
        .todoErrorAlert(model)
    }

    private func openInitialTodoIfPresent() {
        guard let initialTodoID else { return }
        if let todo = model.open(todoID: initialTodoID) {
            selectedTodo = todo
            showingDetail = true
        }
        onInitialTodoOpened()
    }

    private var statusSelector: some View {
        HStack(spacing: DPSpacing.extraSmall) {
            ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                Button {
                    model.selectedStatus = status
                } label: {
                    VStack(spacing: 2) {
                        Text(todoLocalized(status.shortTitleKey))
                            .font(.caption.weight(.semibold))
                            .lineLimit(1)
                        Text("\(model.count(for: status))")
                            .font(.caption2.monospacedDigit())
                    }
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .foregroundStyle(model.selectedStatus == status ? DPColor.textOnDark : status.color)
                    .background(
                        RoundedRectangle(cornerRadius: DPRadius.standard)
                            .fill(model.selectedStatus == status ? status.color : DPColor.backgroundCard)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityLabel(Text(todoLocalized(status.titleKey)))
                .accessibilityValue(Text("\(model.count(for: status))"))
            }
        }
        .padding(.vertical, DPSpacing.extraSmall)
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todo.statusSelector")
    }

    @ViewBuilder
    private var content: some View {
        if model.isLoading && model.board == nil {
            DPLoadingState(label: LocalizedStringKey(todoLocalized("todo.loading")))
        } else if model.board == nil {
            DPErrorState(
                title: LocalizedStringKey(todoLocalized("todo.error.load")),
                retryTitle: LocalizedStringKey(todoLocalized("common.retry")),
                retryAction: { Task { await model.load() } }
            )
        } else if model.selectedTodos.isEmpty {
            DPEmptyState(
                systemImage: "checklist",
                title: LocalizedStringKey(todoLocalized("todo.empty.title")),
                message: LocalizedStringKey(todoLocalized("todo.empty.message"))
            )
            .overlay(alignment: .bottom) {
                Button(todoLocalized("todo.action.add")) {
                    showingCreate = true
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .padding(.bottom, DPSpacing.large)
            }
        } else {
            ScrollView {
                LazyVStack(spacing: DPSpacing.small) {
                    ForEach(Array(model.selectedTodos.enumerated()), id: \.element.id) { index, todo in
                        TodoCard(
                            todo: todo,
                            canMoveUp: index > 0,
                            canMoveDown: index < model.selectedTodos.count - 1,
                            open: {
                                selectedTodo = todo
                                showingDetail = true
                            },
                            moveUp: {
                                Task { await model.moveWithinSelectedColumn(todo, offset: -1) }
                            },
                            moveDown: {
                                Task { await model.moveWithinSelectedColumn(todo, offset: 1) }
                            }
                        )
                    }
                }
                .padding(.horizontal, DPSpacing.medium)
                .padding(.bottom, DPSpacing.large)
            }
            .refreshable { await model.refresh() }
        }
    }
}

private struct TodoCard: View {
    let todo: TodoDTO
    let canMoveUp: Bool
    let canMoveDown: Bool
    let open: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: DPSpacing.small) {
                    HStack(alignment: .top) {
                        Text(todo.title)
                            .font(.headline)
                            .foregroundStyle(DPColor.textPrimary)
                            .multilineTextAlignment(.leading)
                        Spacer(minLength: DPSpacing.small)
                        if todo.isTagged {
                            Label(todoLocalized("todo.label.shared"), systemImage: "person.crop.circle.badge.checkmark")
                                .font(.caption2)
                                .foregroundStyle(DPColor.accent)
                                .labelStyle(.iconOnly)
                        }
                    }

                    if !todo.content.isEmpty {
                        Text(todo.content)
                            .font(.subheadline)
                            .foregroundStyle(DPColor.textSecondary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                    }

                    HStack(spacing: DPSpacing.small) {
                        if let dueDate = todo.dueDate {
                            Label(dueDate.rawValue, systemImage: "calendar")
                                .foregroundStyle(todo.isOverdue ? DPColor.danger : DPColor.textMuted)
                        }
                        if todo.hasAttachments {
                            Image(systemName: "paperclip")
                                .foregroundStyle(DPColor.textMuted)
                                .accessibilityLabel(Text(todoLocalized("todo.label.attachments")))
                        }
                        if todo.isTagged {
                            Text(todo.owner)
                                .foregroundStyle(DPColor.textMuted)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Divider()

            HStack(spacing: 0) {
                Button(action: moveUp) {
                    Label(todoLocalized("todo.action.moveUp"), systemImage: "arrow.up")
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .disabled(!canMoveUp)

                Divider().frame(height: 24)

                Button(action: moveDown) {
                    Label(todoLocalized("todo.action.moveDown"), systemImage: "arrow.down")
                        .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                }
                .disabled(!canMoveDown)
            }
            .font(.caption.weight(.medium))
            .labelStyle(.titleAndIcon)
        }
        .padding(.horizontal, DPSpacing.medium)
        .padding(.top, DPSpacing.medium)
        .background(
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .fill(DPColor.backgroundCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary)
        )
        .accessibilityIdentifier("todo.card.\(todo.id)")
    }
}

private struct TodoDetailSheet: View {
    @ObservedObject var model: TodoViewModel
    let todo: TodoDTO
    let onTodoChanged: () async -> Void
    let dismiss: () -> Void

    @State private var showingEdit = false
    @State private var showingDeleteConfirmation = false
    @State private var showingLeaveConfirmation = false
    @StateObject private var gallery: AttachmentGalleryModel

    init(
        model: TodoViewModel,
        todo: TodoDTO,
        onTodoChanged: @escaping () async -> Void,
        dismiss: @escaping () -> Void
    ) {
        self.model = model
        self.todo = todo
        self.onTodoChanged = onTodoChanged
        self.dismiss = dismiss
        _gallery = StateObject(
            wrappedValue: AttachmentGalleryModel(contextType: .todo, contextId: todo.id)
        )
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent(todoLocalized("todo.field.status")) {
                        Text(todoLocalized(todo.status.titleKey))
                            .foregroundStyle(todo.status.color)
                    }
                    if let dueDate = todo.dueDate {
                        LabeledContent(todoLocalized("todo.field.dueDate"), value: dueDate.rawValue)
                            .foregroundStyle(todo.isOverdue ? DPColor.danger : DPColor.textPrimary)
                    }
                    if todo.isTagged {
                        LabeledContent(todoLocalized("todo.field.owner"), value: todo.owner)
                    }
                }

                if !todo.content.isEmpty {
                    Section(todoLocalized("todo.field.content")) {
                        Text(todo.content)
                            .textSelection(.enabled)
                    }
                }

                if todo.isTagged || !todo.tags.isEmpty {
                    Section(todoLocalized(todo.isTagged ? "todo.field.owner" : "todo.field.tags")) {
                        if todo.isTagged {
                            Label(todo.owner, systemImage: "person.fill")
                        } else {
                            ForEach(Array(todo.tags.enumerated()), id: \.offset) { _, member in
                                Label(member.name, systemImage: "person.fill")
                            }
                        }
                    }
                }

                if todo.hasAttachments {
                    Section(todoLocalized("todo.label.attachments")) {
                        AttachmentGallery(model: gallery)
                    }
                }

                Section(todoLocalized("todo.action.status")) {
                    ForEach(TodoStatus.boardStatuses.filter { $0 != todo.status }, id: \.rawValue) { status in
                        Button {
                            Task {
                                if await model.move(todo, to: status) {
                                    await onTodoChanged()
                                    dismiss()
                                }
                            }
                        } label: {
                            Label(todoLocalized(status.titleKey), systemImage: status.systemImage)
                        }
                        .disabled(model.isSaving)
                    }

                    if todo.status == .done {
                        Button {
                            Task {
                                if await model.reopen(todo) {
                                    await onTodoChanged()
                                    dismiss()
                                }
                            }
                        } label: {
                            Label(todoLocalized("todo.action.reopen"), systemImage: "arrow.uturn.backward")
                        }
                        .disabled(model.isSaving)
                    } else {
                        Button {
                            Task {
                                if await model.complete(todo) {
                                    await onTodoChanged()
                                    dismiss()
                                }
                            }
                        } label: {
                            Label(todoLocalized("todo.action.complete"), systemImage: "checkmark.circle")
                        }
                        .disabled(model.isSaving)
                    }
                }

                Section {
                    if todo.isTagged {
                        Button(todoLocalized("todo.action.leaveTag"), role: .destructive) {
                            showingLeaveConfirmation = true
                        }
                    } else {
                        Button(todoLocalized("todo.action.delete"), role: .destructive) {
                            showingDeleteConfirmation = true
                        }
                    }
                }
            }
            .navigationTitle(todo.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(todoLocalized("common.close"), action: dismiss)
                }
                if !todo.isTagged {
                    ToolbarItem(placement: .primaryAction) {
                        Button(todoLocalized("common.edit")) {
                            showingEdit = true
                        }
                        .disabled(todo.hasAttachments && model.attachmentsByTodoID[todo.uuid] == nil)
                    }
                }
            }
            .task { await model.loadAttachments(for: todo) }
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
            .confirmationDialog(todoLocalized("todo.confirm.deleteTitle"), isPresented: $showingDeleteConfirmation) {
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
            .confirmationDialog(todoLocalized("todo.confirm.leaveTitle"), isPresented: $showingLeaveConfirmation) {
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
            .todoErrorAlert(model)
        }
    }
}

private struct TodoFormSheet: View {
    let titleKey: String
    let friends: [FriendDTO]
    let isSaving: Bool
    let save: (TodoDraft) async -> Bool

    @ObservedObject var model: TodoViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TodoDraft
    @State private var didSave = false
    @StateObject private var attachmentModel: AttachmentPickerModel

    init(
        titleKey: String,
        initialDraft: TodoDraft,
        friends: [FriendDTO],
        model: TodoViewModel,
        targetTodoID: String?,
        existingAttachments: [AttachmentDTO],
        isSaving: Bool,
        save: @escaping (TodoDraft) async -> Bool
    ) {
        self.titleKey = titleKey
        self.friends = friends
        self.model = model
        self.isSaving = isSaving
        self.save = save
        _draft = State(initialValue: initialDraft)
        _attachmentModel = StateObject(
            wrappedValue: AttachmentPickerModel(
                contextType: .todo,
                targetContextId: targetTodoID,
                existingAttachments: existingAttachments
            )
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField(todoLocalized("todo.field.title"), text: $draft.title)
                        .textInputAutocapitalization(.sentences)
                    HStack {
                        Spacer()
                        Text("\(draft.title.count)/50")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(draft.title.count > 50 ? DPColor.danger : DPColor.textMuted)
                    }
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 100)
                        .overlay(alignment: .topLeading) {
                            if draft.content.isEmpty {
                                Text(todoLocalized("todo.field.content"))
                                    .foregroundStyle(DPColor.textMuted)
                                    .padding(.top, 8)
                                    .padding(.leading, 5)
                                    .allowsHitTesting(false)
                            }
                        }
                }

                Section(todoLocalized("todo.field.status")) {
                    Picker(todoLocalized("todo.field.status"), selection: $draft.status) {
                        ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                            Text(todoLocalized(status.shortTitleKey)).tag(status)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                }

                Section(todoLocalized("todo.field.dueDate")) {
                    Toggle(todoLocalized("todo.field.setDueDate"), isOn: $draft.hasDueDate)
                    if draft.hasDueDate {
                        DatePicker(
                            todoLocalized("todo.field.dueDate"),
                            selection: $draft.dueDate,
                            displayedComponents: .date
                        )
                    }
                }

                if !friends.isEmpty {
                    Section(todoLocalized("todo.field.tags")) {
                        ForEach(friends, id: \.id) { friend in
                            Button {
                                if draft.taggedFriendIDs.contains(friend.id) {
                                    draft.taggedFriendIDs.remove(friend.id)
                                } else {
                                    draft.taggedFriendIDs.insert(friend.id)
                                }
                            } label: {
                                HStack {
                                    Text(friend.name)
                                        .foregroundStyle(DPColor.textPrimary)
                                    Spacer()
                                    if draft.taggedFriendIDs.contains(friend.id) {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(DPColor.accent)
                                    }
                                }
                                .frame(minHeight: DPSize.minimumTouchTarget)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section(todoLocalized("todo.label.attachments")) {
                    AttachmentPicker(model: attachmentModel)
                }
            }
            .navigationTitle(todoLocalized(titleKey))
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(isSaving || attachmentModel.isBusy || attachmentModel.attachmentSessionId != nil)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(todoLocalized("common.cancel")) {
                        Task {
                            if await attachmentModel.discard() {
                                dismiss()
                            }
                        }
                    }
                    .disabled(isSaving || attachmentModel.isBusy)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(todoLocalized("common.save")) {
                        Task {
                            guard let attachments = await attachmentModel.resultForSave() else { return }
                            var submission = draft
                            submission.attachmentSessionId = attachments.attachmentSessionId
                            submission.orderedAttachmentIDs = attachments.orderedAttachmentIds
                            if await save(submission) {
                                didSave = true
                                dismiss()
                            }
                        }
                    }
                    .disabled(!draft.canSave || isSaving || attachmentModel.isBusy)
                }
            }
            .onDisappear {
                guard !didSave else { return }
                Task { await attachmentModel.discard() }
            }
            .todoErrorAlert(model)
        }
    }
}

private struct TodoErrorAlertModifier: ViewModifier {
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
    func todoErrorAlert(_ model: TodoViewModel) -> some View {
        modifier(TodoErrorAlertModifier(model: model))
    }
}

extension TodoStatus {
    static let boardStatuses: [TodoStatus] = [.todo, .inProgress, .done]

    var titleKey: String {
        switch self {
        case .todo: "todo.status.todo"
        case .inProgress: "todo.status.inProgress"
        case .done: "todo.status.done"
        case .unknown: "todo.status.unknown"
        }
    }

    var shortTitleKey: String {
        switch self {
        case .todo: "todo.statusShort.todo"
        case .inProgress: "todo.statusShort.inProgress"
        case .done: "todo.statusShort.done"
        case .unknown: "todo.status.unknown"
        }
    }

    var systemImage: String {
        switch self {
        case .todo: "list.bullet"
        case .inProgress: "clock"
        case .done: "checkmark.circle"
        case .unknown: "questionmark.circle"
        }
    }

    var color: Color {
        switch self {
        case .todo: DPColor.accent
        case .inProgress: DPColor.warning
        case .done: DPColor.success
        case .unknown: DPColor.textMuted
        }
    }
}
