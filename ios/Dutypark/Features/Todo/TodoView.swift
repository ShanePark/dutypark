import SwiftUI

func todoLocalized(_ key: String, locale: Locale? = nil) -> String {
    AppLocalization.string(key, table: "Todo", locale: locale)
}

enum TodoBoardLayout {
    static let mobileColumnWidthRatio: CGFloat = 0.62
    static let boardPadding: CGFloat = 8
    static let columnGap: CGFloat = 10
    static let columnRadius: CGFloat = 12
    static let cardRadius: CGFloat = 14
    static let dragHandleSize: CGFloat = 44
    static let dragActivationDistance: CGFloat = 2
    static let dragCollisionHysteresis: CGFloat = 2
    static let dragPushAnimationDuration = 0.1

    static func mobileColumnWidth(in containerWidth: CGFloat) -> CGFloat {
        containerWidth * mobileColumnWidthRatio
    }

    /// Gives the first and last columns enough scroll content on both sides to
    /// use the same centered snap position as the middle column.
    static func centeredColumnInset(containerWidth: CGFloat, columnWidth: CGFloat) -> CGFloat {
        max(boardPadding, (containerWidth - columnWidth) / 2)
    }

    static func adjacentColumnPeekWidth(containerWidth: CGFloat, columnWidth: CGFloat) -> CGFloat {
        max(0, centeredColumnInset(containerWidth: containerWidth, columnWidth: columnWidth) - columnGap)
    }
}

nonisolated enum TodoFormDismissalAction: Equatable, Sendable {
    case dismiss
    case confirmDiscard
    case ignore
}

nonisolated enum TodoFormSubmissionPolicy {
    static func canBegin(isSubmitting: Bool, canSave: Bool, isBusy: Bool) -> Bool {
        !isSubmitting && canSave && !isBusy
    }
}

enum TodoFormDismissalPolicy {
    static func isDirty(
        initialDraft: TodoDraft,
        draft: TodoDraft,
        initialAttachmentIDs: [AttachmentID],
        attachmentIDs: [AttachmentID],
        hasAttachmentSession: Bool
    ) -> Bool {
        draft != initialDraft
            || initialAttachmentIDs != attachmentIDs
            || hasAttachmentSession
    }

    static func action(isDirty: Bool, isBusy: Bool) -> TodoFormDismissalAction {
        guard !isBusy else { return .ignore }
        return isDirty ? .confirmDiscard : .dismiss
    }
}

/// The single Todo creation presentation shared by the Todo board and Calendar quick-add.
struct TodoCreateModal: View {
    @ObservedObject var model: TodoViewModel
    let initialStatus: TodoStatus
    let friends: [FriendDTO]
    let refreshBoardAfterCreate: Bool
    let onCreated: () async -> Void
    let onDismiss: () -> Void

    @State private var dismissRequest = 0
    @State private var isFormBusy = false

    var body: some View {
        DPModalOverlay(
            onDismiss: onDismiss,
            canDismiss: !isFormBusy && !model.isSaving,
            onDismissRequest: { _ in dismissRequest += 1 }
        ) { availableSize, dismiss in
            TodoFormSheet(
                titleKey: "todo.form.createTitle",
                initialDraft: TodoDraft(status: initialStatus),
                friends: friends,
                model: model,
                targetTodoID: nil,
                existingAttachments: [],
                isSaving: model.isSaving,
                maximumHeight: availableSize.height,
                dismissAction: dismiss,
                savedDismissAction: dismiss,
                dismissRequest: dismissRequest,
                onBusyChange: { isFormBusy = $0 }
            ) { draft in
                let created = await model.create(
                    draft: draft,
                    refreshBoard: refreshBoardAfterCreate
                )
                if created { await onCreated() }
                return created
            }
        }
    }
}

struct TodoView: View {
    let initialTodoID: TodoID?
    let onTodoChanged: () async -> Void
    let onInitialTodoOpened: () -> Void

    @StateObject private var model: TodoViewModel
    @State private var selectedTodo: TodoDTO?
    @State private var showingDetail = false
    @State private var showingCreate = false
    @State private var showingHelp = false
    @State private var detailCanDismiss = true
    @State private var detailDismissRequest = 0
    @State private var visibleStatus: TodoStatus?
    @State private var draggedTodoID: TodoID?
    @State private var dragTargetStatus: TodoStatus?
    @State private var dragTargetTodoID: TodoID?
    @State private var dragInsertAfter = false
    @State private var dragLocation: CGPoint?
    @State private var dragPreviewSize: CGSize?
    @State private var dragGrabOffset: CGSize?
    @State private var pendingDropPlacement: TodoDragPlacement?
    @State private var dragReferenceCardTargets: [TodoCardDropTarget] = []
    @State private var dragReferenceColumnTargets: [TodoColumnDropTarget] = []
    @State private var cardDropTargets: [TodoCardDropTarget] = []
    @State private var columnDropTargets: [TodoColumnDropTarget] = []
    @State private var statusDropTargets: [TodoStatusDropTarget] = []

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
        VStack(spacing: 0) {
            statusSelector
                .padding(.horizontal, TodoBoardLayout.boardPadding)
                .padding(.bottom, DPSpacing.compact)

            content
        }
        .background(DPColor.backgroundSecondary)
        .coordinateSpace(name: TodoDragCoordinateSpace.name)
        .onPreferenceChange(TodoCardDropTargetPreferenceKey.self) { cardDropTargets = $0 }
        .onPreferenceChange(TodoColumnDropTargetPreferenceKey.self) { columnDropTargets = $0 }
        .onPreferenceChange(TodoStatusDropTargetPreferenceKey.self) { statusDropTargets = $0 }
        .overlay {
            if let draggedTodoID,
               let dragLocation,
               let dragPreviewSize,
               let dragGrabOffset,
               let todo = draggedTodo(withID: draggedTodoID) {
                TodoDragPreview(
                    todo: todo,
                    status: todo.status,
                    size: dragPreviewSize
                )
                    .position(
                        x: dragLocation.x - dragGrabOffset.width,
                        y: dragLocation.y - dragGrabOffset.height
                    )
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .topBarTrailing) {
                Button {
                    withoutPresentationAnimation { showingHelp = true }
                } label: {
                    Image(systemName: "questionmark.circle")
                        .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityLabel(todoLocalized("todo.help.open"))
                .accessibilityIdentifier("todo.help")

                Button {
                    withoutPresentationAnimation { showingCreate = true }
                } label: {
                    Image(systemName: "plus")
                        .frame(minWidth: DPSize.minimumTouchTarget, minHeight: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .accessibilityRepresentation {
                    Button {
                        withoutPresentationAnimation { showingCreate = true }
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
            visibleStatus = model.selectedStatus
            openInitialTodoIfPresent()
        }
        .onChange(of: model.selectedStatus) { _, status in
            withAnimation(.easeInOut(duration: 0.2)) {
                visibleStatus = status
            }
        }
        .onChange(of: visibleStatus) { _, status in
            if let status, status != model.selectedStatus {
                model.selectedStatus = status
            }
        }
        .fullScreenCover(isPresented: $showingCreate) {
            TodoCreateModal(
                model: model,
                initialStatus: model.selectedStatus,
                friends: model.friends,
                refreshBoardAfterCreate: true,
                onCreated: onTodoChanged,
                onDismiss: { showingCreate = false }
            )
        }
        .fullScreenCover(isPresented: $showingHelp) {
            DPModalOverlay(onDismiss: { showingHelp = false }) { availableSize, dismiss in
                TodoHelpModal(maximumHeight: availableSize.height, dismiss: dismiss)
            }
        }
        .fullScreenCover(isPresented: $showingDetail) {
            if let selectedTodo {
                DPModalOverlay(
                    onDismiss: { showingDetail = false },
                    canDismiss: detailCanDismiss && !model.isSaving,
                    onDismissRequest: { _ in detailDismissRequest += 1 }
                ) { availableSize, dismiss in
                    TodoDetailModal(
                        model: model,
                        todo: selectedTodo,
                        maximumHeight: availableSize.height,
                        onTodoChanged: onTodoChanged,
                        onDismissabilityChange: { detailCanDismiss = $0 },
                        dismissRequest: detailDismissRequest,
                        dismiss: dismiss
                    )
                }
            }
        }
        .todoErrorAlert(model)
    }

    private func openInitialTodoIfPresent() {
        guard let initialTodoID else { return }
        if let todo = model.open(todoID: initialTodoID) {
            selectedTodo = todo
            withoutPresentationAnimation { showingDetail = true }
        }
        onInitialTodoOpened()
    }

    private func draggedTodo(withID id: TodoID) -> TodoDTO? {
        TodoStatus.boardStatuses
            .lazy
            .flatMap { model.todos(for: $0) }
            .first { $0.uuid == id }
    }

    private func handleDrop(
        todoID: TodoID,
        destinationStatus: TodoStatus,
        targetTodoID: TodoID? = nil,
        insertAfter: Bool = false,
        visualPlacement: TodoDragPlacement? = nil
    ) {
        clearInteractiveDrag()
        pendingDropPlacement = visualPlacement
        Task {
            let succeeded = await model.drop(
                todoID: todoID,
                into: destinationStatus,
                relativeTo: targetTodoID,
                insertAfter: insertAfter
            )
            pendingDropPlacement = nil
            if succeeded {
                await onTodoChanged()
            }
        }
    }

    private func updateInteractiveDrag(todo: TodoDTO, location: CGPoint) {
        guard !model.isSaving else { return }
        var previewSize = dragPreviewSize
        var grabOffset = dragGrabOffset
        if draggedTodoID != todo.uuid {
            draggedTodoID = todo.uuid
            dragReferenceCardTargets = cardDropTargets
            dragReferenceColumnTargets = columnDropTargets
            if let frame = cardDropTargets.last(where: { $0.todoID == todo.uuid })?.frame {
                previewSize = frame.size
                grabOffset = CGSize(
                    width: location.x - frame.midX,
                    height: location.y - frame.midY
                )
                dragPreviewSize = previewSize
                dragGrabOffset = grabOffset
            }
        }
        dragLocation = location
        let movingFrame = previewSize.flatMap { size in
            grabOffset.map { offset in
                CGRect(
                    x: location.x - offset.width - (size.width / 2),
                    y: location.y - offset.height - (size.height / 2),
                    width: size.width,
                    height: size.height
                )
            }
        }
        let previousTarget = dragTargetStatus.map {
            TodoResolvedDropTarget(
                status: $0,
                todoID: dragTargetTodoID,
                insertAfter: dragInsertAfter
            )
        }
        let target = TodoDragTargetResolver.resolve(
            location: location,
            draggedTodoID: todo.uuid,
            cards: dragReferenceCardTargets,
            columns: dragReferenceColumnTargets,
            statuses: statusDropTargets,
            movingFrame: movingFrame,
            previousTarget: previousTarget
        )
        withAnimation(.snappy(duration: TodoBoardLayout.dragPushAnimationDuration, extraBounce: 0)) {
            dragTargetStatus = target?.status
            dragTargetTodoID = target?.todoID
            dragInsertAfter = target?.insertAfter ?? false
        }
    }

    private func finishInteractiveDrag(todo: TodoDTO) {
        let destinationStatus = dragTargetStatus
        let targetTodoID = dragTargetTodoID
        let insertAfter = dragInsertAfter

        guard let destinationStatus else {
            clearInteractiveDrag()
            return
        }
        let placement = destinationStatus == todo.status
            ? TodoDragPlacement(
                todoID: todo.uuid,
                destinationStatus: destinationStatus,
                targetTodoID: targetTodoID,
                insertAfter: insertAfter
            )
            : nil
        handleDrop(
            todoID: todo.uuid,
            destinationStatus: destinationStatus,
            targetTodoID: targetTodoID,
            insertAfter: insertAfter,
            visualPlacement: placement
        )
    }

    private func clearInteractiveDrag() {
        draggedTodoID = nil
        dragTargetStatus = nil
        dragTargetTodoID = nil
        dragInsertAfter = false
        dragLocation = nil
        dragPreviewSize = nil
        dragGrabOffset = nil
        dragReferenceCardTargets = []
        dragReferenceColumnTargets = []
    }

    private var statusSelector: some View {
        HStack(spacing: DPSpacing.small) {
            ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                Button {
                    model.selectedStatus = status
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 15, weight: .semibold))
                        Text(todoLocalized(status.shortTitleKey))
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Text(verbatim: "\(model.count(for: status))")
                            .font(DPFont.bold(size: 11, relativeTo: .caption2))
                            .foregroundStyle(model.selectedStatus == status ? DPColor.textOnDark : DPColor.textMuted)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(
                                Capsule().fill(model.selectedStatus == status ? status.color : DPColor.backgroundTertiary)
                            )
                    }
                    .padding(.horizontal, 9)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .foregroundStyle(status.color)
                    .background(
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .fill(DPColor.backgroundCard)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: DPRadius.large)
                            .stroke(
                                dragTargetStatus == status
                                    ? DPColor.accent
                                    : (model.selectedStatus == status ? status.color : DPColor.borderPrimary),
                                lineWidth: dragTargetStatus == status || model.selectedStatus == status ? 2 : 1
                            )
                    )
                }
                .buttonStyle(.plain)
                .background {
                    GeometryReader { proxy in
                        Color.clear.preference(
                            key: TodoStatusDropTargetPreferenceKey.self,
                            value: [TodoStatusDropTarget(
                                status: status,
                                frame: proxy.frame(in: .named(TodoDragCoordinateSpace.name))
                            )]
                        )
                    }
                }
                .accessibilityLabel(Text(todoLocalized(status.titleKey)))
                .accessibilityValue(Text("\(model.count(for: status))"))
            }
        }
        .padding(.top, DPSpacing.small)
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
        } else {
            GeometryReader { proxy in
                let columnWidth = TodoBoardLayout.mobileColumnWidth(in: proxy.size.width)
                let centeredColumnInset = TodoBoardLayout.centeredColumnInset(
                    containerWidth: proxy.size.width,
                    columnWidth: columnWidth
                )
                ScrollView(.horizontal) {
                    LazyHStack(alignment: .top, spacing: TodoBoardLayout.columnGap) {
                        ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                            TodoKanbanColumn(
                                status: status,
                                count: model.count(for: status),
                                todos: displayedTodos(for: status),
                                width: columnWidth,
                                draggedTodoID: draggedTodoID,
                                dragTargetStatus: dragTargetStatus,
                                dragTargetTodoID: dragTargetTodoID,
                                dragInsertAfter: dragInsertAfter,
                                add: {
                                    model.selectedStatus = status
                                    withoutPresentationAnimation { showingCreate = true }
                                },
                                select: { model.selectedStatus = status },
                                open: { todo in
                                    selectedTodo = todo
                                    withoutPresentationAnimation { showingDetail = true }
                                },
                                move: { todo, offset in
                                    model.selectedStatus = status
                                    Task {
                                        if await model.moveWithinSelectedColumn(todo, offset: offset) {
                                            await onTodoChanged()
                                        }
                                    }
                                },
                                updateDrag: updateInteractiveDrag,
                                finishDrag: finishInteractiveDrag,
                                drop: { todoID, destinationStatus, targetTodoID, insertAfter in
                                    handleDrop(
                                        todoID: todoID,
                                        destinationStatus: destinationStatus,
                                        targetTodoID: targetTodoID,
                                        insertAfter: insertAfter
                                    )
                                }
                            )
                            .id(status)
                            .containerRelativeFrame(.vertical)
                        }
                    }
                    .scrollTargetLayout()
                    .padding(.horizontal, centeredColumnInset)
                    .padding(.bottom, DPSpacing.small)
                }
                .scrollIndicators(.hidden)
                .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
                .scrollPosition(id: $visibleStatus, anchor: .center)
                .refreshable { await model.refresh() }
            }
        }
    }

    private func displayedTodos(for status: TodoStatus) -> [TodoDTO] {
        let columns = Dictionary(
            uniqueKeysWithValues: TodoStatus.boardStatuses.map { ($0, model.todos(for: $0)) }
        )
        let activePlacement: TodoDragPlacement? = draggedTodoID.flatMap { todoID in
            guard let todo = draggedTodo(withID: todoID) else { return nil }
            return dragTargetStatus.flatMap {
                guard $0 == todo.status else { return nil }
                return TodoDragPlacement(
                    todoID: todoID,
                    destinationStatus: $0,
                    targetTodoID: dragTargetTodoID,
                    insertAfter: dragInsertAfter
                )
            }
        }
        return TodoDragProjection.columns(
            projecting: activePlacement ?? pendingDropPlacement,
            from: columns
        )[status] ?? []
    }
}

private struct TodoKanbanColumn: View {
    let status: TodoStatus
    let count: Int
    let todos: [TodoDTO]
    let width: CGFloat
    let draggedTodoID: TodoID?
    let dragTargetStatus: TodoStatus?
    let dragTargetTodoID: TodoID?
    let dragInsertAfter: Bool
    let add: () -> Void
    let select: () -> Void
    let open: (TodoDTO) -> Void
    let move: (TodoDTO, Int) -> Void
    let updateDrag: (TodoDTO, CGPoint) -> Void
    let finishDrag: (TodoDTO) -> Void
    let drop: (TodoID, TodoStatus, TodoID?, Bool) -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.extraSmall) {
                Button(action: select) {
                    HStack(spacing: 6) {
                        Image(systemName: status.systemImage)
                            .font(.system(size: 16, weight: .semibold))
                        Text(todoLocalized(status.shortTitleKey))
                            .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                        Spacer(minLength: 4)
                        Text(verbatim: "\(count)")
                            .font(DPFont.bold(size: 12, relativeTo: .caption))
                            .frame(minWidth: 24)
                    }
                    .foregroundStyle(status.color)
                    .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                Button(action: add) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(DPColor.textOnDark)
                        .frame(width: 24, height: 24)
                        .background(DPColor.accent, in: RoundedRectangle(cornerRadius: DPRadius.compact))
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todoLocalized("todo.action.add"))
            }
            .padding(.leading, DPSpacing.small)
            .background(DPColor.backgroundCard)
            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            .padding(.horizontal, DPSpacing.compact)
            .padding(.top, DPSpacing.compact)
            .padding(.bottom, DPSpacing.compact)

            ScrollView(.vertical) {
                LazyVStack(spacing: DPSpacing.small) {
                    if todos.isEmpty {
                        Button(action: add) {
                            VStack(spacing: DPSpacing.small) {
                                Image(systemName: "plus")
                                    .font(.system(size: 18, weight: .bold))
                                Text(todoLocalized("todo.action.add"))
                                    .font(DPTypography.caption)
                            }
                            .foregroundStyle(DPColor.accent)
                            .frame(maxWidth: .infinity, minHeight: 112)
                            .background(DPColor.backgroundCard.opacity(0.6))
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.large))
                            .overlay(
                                RoundedRectangle(cornerRadius: DPRadius.large)
                                    .stroke(DPColor.accent.opacity(0.25), style: StrokeStyle(lineWidth: 1, dash: [5]))
                            )
                        }
                        .buttonStyle(.plain)
                    } else {
                        ForEach(Array(todos.enumerated()), id: \.element.id) { index, todo in
                            TodoCard(
                                todo: todo,
                                status: status,
                                canMoveUp: index > 0,
                                canMoveDown: index < todos.count - 1,
                                open: { open(todo) },
                                moveUp: { move(todo, -1) },
                                moveDown: { move(todo, 1) },
                                moveToStatus: { destination in
                                    drop(todo.uuid, destination, nil, false)
                                },
                                dropEdge: dragTargetStatus == status && dragTargetTodoID == todo.uuid
                                    ? (dragInsertAfter ? .after : .before)
                                    : nil,
                                updateDrag: { location in updateDrag(todo, location) },
                                finishDrag: { finishDrag(todo) }
                            )
                            .opacity(draggedTodoID == todo.uuid ? 0 : 1)
                        }
                    }

                    TodoColumnDropZone(
                        isTargeted: draggedTodoID != nil
                            && dragTargetStatus == status
                            && dragTargetTodoID == nil
                    )
                }
                .animation(
                    .snappy(duration: TodoBoardLayout.dragPushAnimationDuration, extraBounce: 0),
                    value: todos.map(\.uuid)
                )
                .padding(.horizontal, DPSpacing.compact)
                .padding(.bottom, DPSpacing.compact)
            }
            .scrollIndicators(.hidden)
        }
        .frame(width: width)
        .background {
            ZStack {
                DPColor.backgroundTertiary
                status.color.opacity(status == .todo ? 0.12 : 0.15)
            }
        }
        .background {
            GeometryReader { proxy in
                Color.clear.preference(
                    key: TodoColumnDropTargetPreferenceKey.self,
                    value: [TodoColumnDropTarget(
                        status: status,
                        frame: proxy.frame(in: .named(TodoDragCoordinateSpace.name))
                    )]
                )
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: TodoBoardLayout.columnRadius))
        .overlay(
            RoundedRectangle(cornerRadius: TodoBoardLayout.columnRadius)
                .stroke(
                    dragTargetStatus == status ? status.color : .clear,
                    style: StrokeStyle(lineWidth: 2, dash: [7, 5])
                )
                .allowsHitTesting(false)
        )
        .accessibilityIdentifier("todo.column.\(status.rawValue)")
    }
}

private struct TodoCard: View {
    let todo: TodoDTO
    let status: TodoStatus
    let canMoveUp: Bool
    let canMoveDown: Bool
    let open: () -> Void
    let moveUp: () -> Void
    let moveDown: () -> Void
    let moveToStatus: (TodoStatus) -> Void
    let dropEdge: TodoDropEdge?
    let updateDrag: (CGPoint) -> Void
    let finishDrag: () -> Void
    var measuresDropTarget = true

    var body: some View {
        ZStack(alignment: .topTrailing) {
            Button(action: open) {
                VStack(alignment: .leading, spacing: 0) {
                    HStack(alignment: .top, spacing: DPSpacing.small) {
                        Text(todo.title)
                            .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                            .foregroundStyle(DPColor.textPrimary)
                            .multilineTextAlignment(.leading)
                            .lineSpacing(1)
                        Spacer(minLength: 0)
                        if todo.hasAttachments {
                            Image(systemName: "paperclip")
                                .font(.system(size: 15))
                                .foregroundStyle(DPColor.textMuted)
                                .accessibilityLabel(Text(todoLocalized("todo.label.attachments")))
                        }
                        Spacer(minLength: DPSize.minimumTouchTarget)
                    }

                    if !todo.content.isEmpty {
                        Text(todo.content)
                            .font(DPFont.light(size: 12, relativeTo: .caption))
                            .foregroundStyle(DPColor.textSecondary)
                            .lineLimit(2)
                            .lineSpacing(1)
                            .multilineTextAlignment(.leading)
                            .padding(.top, 6)
                    }

                    let names = todo.isTagged ? [todo.taggedByMember?.name ?? todo.owner] : todo.tags.map(\.name)
                    if !names.isEmpty {
                        HStack(spacing: 4) {
                            ForEach(Array(names.prefix(2).enumerated()), id: \.offset) { _, name in
                                Text(name)
                                    .font(DPFont.light(size: 11, relativeTo: .caption2))
                                    .foregroundStyle(DPColor.textSecondary)
                                    .lineLimit(1)
                                    .padding(.horizontal, 7)
                                    .padding(.vertical, 4)
                                    .background(DPColor.backgroundTertiary, in: Capsule())
                            }
                            if names.count > 2 {
                                Text(verbatim: "+\(names.count - 2)")
                                    .font(DPFont.bold(size: 10, relativeTo: .caption2))
                                    .foregroundStyle(DPColor.textMuted)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .padding(.top, DPSpacing.small)
                    }

                    if let dueDate = todo.dueDate {
                        Label(dueDate.rawValue, systemImage: "calendar.badge.checkmark")
                            .font(DPFont.light(size: 12, relativeTo: .caption))
                            .foregroundStyle(todo.isOverdue ? DPColor.danger : DPColor.textSecondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(
                                todo.isOverdue ? DPColor.dangerSoft : DPColor.backgroundTertiary,
                                in: Capsule()
                            )
                            .padding(.top, DPSpacing.small)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            Image(systemName: "line.3.horizontal")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(DPColor.textMuted)
                .frame(width: TodoBoardLayout.dragHandleSize, height: TodoBoardLayout.dragHandleSize)
                .contentShape(Rectangle())
                .simultaneousGesture(
                    DragGesture(
                        minimumDistance: TodoBoardLayout.dragActivationDistance,
                        coordinateSpace: .named(TodoDragCoordinateSpace.name)
                    )
                    .onChanged { value in
                        if TodoHandleDragActivation.shouldReorder(translation: value.translation) {
                            updateDrag(value.location)
                        }
                    }
                    .onEnded { _ in finishDrag() }
                )
                .accessibilityHidden(true)
        }
        .padding(14)
        .background(DPColor.backgroundCard)
        .clipShape(RoundedRectangle(cornerRadius: TodoBoardLayout.cardRadius))
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: TodoBoardLayout.cardRadius)
                    .stroke(dropEdge == nil ? DPColor.borderPrimary : status.color, lineWidth: dropEdge == nil ? 1 : 2)

                if let dropEdge {
                    VStack(spacing: 0) {
                        if dropEdge == .after { Spacer(minLength: 0) }
                        Capsule()
                            .fill(status.color)
                            .frame(height: 4)
                            .padding(.horizontal, 10)
                            .offset(y: dropEdge == .before ? -8 : 8)
                        if dropEdge == .before { Spacer(minLength: 0) }
                    }
                }
            }
            .allowsHitTesting(false)
        )
        .shadow(color: .black.opacity(0.05), radius: 2, y: 1)
        .background {
            if measuresDropTarget {
                GeometryReader { proxy in
                    Color.clear
                        .preference(
                            key: TodoCardDropTargetPreferenceKey.self,
                            value: [TodoCardDropTarget(
                                todoID: todo.uuid,
                                status: status,
                                frame: proxy.frame(in: .named(TodoDragCoordinateSpace.name))
                            )]
                        )
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityAction(named: Text(todoLocalized("todo.action.moveUp"))) {
            if canMoveUp { moveUp() }
        }
        .accessibilityAction(named: Text(todoLocalized("todo.action.moveDown"))) {
            if canMoveDown { moveDown() }
        }
        .accessibilityActions {
            ForEach(TodoStatus.boardStatuses.filter { $0 != status }, id: \.rawValue) { destination in
                Button(todoLocalized(destination.titleKey)) {
                    moveToStatus(destination)
                }
            }
        }
        .accessibilityHint(todoLocalized("todo.drag.hint"))
        .accessibilityIdentifier("todo.card.\(todo.id)")
    }
}

enum TodoHandleDragActivation {
    static func shouldReorder(translation: CGSize) -> Bool {
        let horizontal = abs(translation.width)
        let vertical = abs(translation.height)
        return hypot(horizontal, vertical) >= TodoBoardLayout.dragActivationDistance
    }
}

private enum TodoDropEdge: Equatable {
    case before
    case after
}

private struct TodoColumnDropZone: View {
    let isTargeted: Bool

    var body: some View {
        Label(todoLocalized("todo.drag.dropHere"), systemImage: "arrow.down.to.line")
            .font(DPTypography.caption)
            .foregroundStyle(isTargeted ? DPColor.accent : DPColor.textMuted)
            .frame(maxWidth: .infinity, minHeight: DPSize.minimumTouchTarget)
            .opacity(isTargeted ? 1 : 0)
            .contentShape(Rectangle())
            .accessibilityHidden(true)
    }
}

private struct TodoDragPreview: View {
    let todo: TodoDTO
    let status: TodoStatus
    let size: CGSize

    var body: some View {
        TodoCard(
            todo: todo,
            status: status,
            canMoveUp: false,
            canMoveDown: false,
            open: {},
            moveUp: {},
            moveDown: {},
            moveToStatus: { _ in },
            dropEdge: nil,
            updateDrag: { _ in },
            finishDrag: {},
            measuresDropTarget: false
        )
        .frame(width: size.width, height: size.height)
        .overlay(
            RoundedRectangle(cornerRadius: TodoBoardLayout.cardRadius)
                .stroke(status.color, lineWidth: 2)
        )
        .shadow(color: .black.opacity(0.18), radius: 12, y: 6)
    }
}

struct TodoDragPlacement: Equatable {
    let todoID: TodoID
    let destinationStatus: TodoStatus
    let targetTodoID: TodoID?
    let insertAfter: Bool
}

enum TodoDragProjection {
    static func columns(
        projecting placement: TodoDragPlacement?,
        from columns: [TodoStatus: [TodoDTO]]
    ) -> [TodoStatus: [TodoDTO]] {
        guard let placement else { return columns }

        var result = columns
        guard let sourceItems = result[placement.destinationStatus],
              let movingTodo = sourceItems.first(where: { $0.uuid == placement.todoID }) else {
            return columns
        }

        var destination = sourceItems
        destination.removeAll { $0.uuid == placement.todoID }
        let insertionIndex: Int
        if let targetTodoID = placement.targetTodoID,
           let targetIndex = destination.firstIndex(where: { $0.uuid == targetTodoID }) {
            insertionIndex = targetIndex + (placement.insertAfter ? 1 : 0)
        } else {
            insertionIndex = destination.endIndex
        }
        destination.insert(movingTodo, at: min(insertionIndex, destination.endIndex))
        result[placement.destinationStatus] = destination
        return result
    }
}

private enum TodoDragCoordinateSpace {
    static let name = "todo-board-drag"
}

struct TodoCardDropTarget: Equatable {
    let todoID: TodoID
    let status: TodoStatus
    let frame: CGRect
}

struct TodoColumnDropTarget: Equatable {
    let status: TodoStatus
    let frame: CGRect
}

struct TodoStatusDropTarget: Equatable {
    let status: TodoStatus
    let frame: CGRect
}

private struct TodoCardDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [TodoCardDropTarget] = []
    static func reduce(value: inout [TodoCardDropTarget], nextValue: () -> [TodoCardDropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TodoColumnDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [TodoColumnDropTarget] = []
    static func reduce(value: inout [TodoColumnDropTarget], nextValue: () -> [TodoColumnDropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

private struct TodoStatusDropTargetPreferenceKey: PreferenceKey {
    static let defaultValue: [TodoStatusDropTarget] = []
    static func reduce(value: inout [TodoStatusDropTarget], nextValue: () -> [TodoStatusDropTarget]) {
        value.append(contentsOf: nextValue())
    }
}

struct TodoResolvedDropTarget: Equatable {
    let status: TodoStatus
    let todoID: TodoID?
    let insertAfter: Bool
}

enum TodoDragTargetResolver {
    static func resolve(
        location: CGPoint,
        draggedTodoID: TodoID,
        cards: [TodoCardDropTarget],
        columns: [TodoColumnDropTarget],
        statuses: [TodoStatusDropTarget],
        movingFrame: CGRect? = nil,
        previousTarget: TodoResolvedDropTarget? = nil
    ) -> TodoResolvedDropTarget? {
        if let status = statuses.last(where: { $0.frame.contains(location) })?.status {
            return TodoResolvedDropTarget(status: status, todoID: nil, insertAfter: false)
        }

        if let source = cards.last(where: { $0.todoID == draggedTodoID }),
           let movingFrame,
           source.frame.minX...source.frame.maxX ~= movingFrame.midX,
           let edgeTarget = resolveVerticalEdgeCollision(
               source: source,
               movingFrame: movingFrame,
               cards: cards,
               previousTarget: previousTarget
           ) {
            return edgeTarget
        }

        if let card = cards.last(where: {
            $0.todoID != draggedTodoID && $0.frame.contains(location)
        }) {
            return TodoResolvedDropTarget(
                status: card.status,
                todoID: card.todoID,
                insertAfter: location.y >= card.frame.midY
            )
        }

        // A two-point movement should activate the handle without accidentally
        // sending the card to the end of its own column.
        if cards.contains(where: { $0.todoID == draggedTodoID && $0.frame.contains(location) }) {
            return nil
        }

        guard let column = columns.last(where: { $0.frame.contains(location) }) else {
            return nil
        }

        let candidates = cards
            .filter { $0.status == column.status && $0.todoID != draggedTodoID }
            .sorted { $0.frame.minY < $1.frame.minY }

        guard let last = candidates.last else {
            return TodoResolvedDropTarget(status: column.status, todoID: nil, insertAfter: false)
        }
        guard location.y <= last.frame.maxY else {
            return TodoResolvedDropTarget(status: column.status, todoID: nil, insertAfter: false)
        }

        let nearest = candidates.min {
            abs($0.frame.midY - location.y) < abs($1.frame.midY - location.y)
        } ?? last
        return TodoResolvedDropTarget(
            status: column.status,
            todoID: nearest.todoID,
            insertAfter: location.y >= nearest.frame.midY
        )
    }

    private static func resolveVerticalEdgeCollision(
        source: TodoCardDropTarget,
        movingFrame: CGRect,
        cards: [TodoCardDropTarget],
        previousTarget: TodoResolvedDropTarget?
    ) -> TodoResolvedDropTarget? {
        let candidates = cards
            .filter {
                $0.status == source.status
                    && $0.todoID != source.todoID
                    && movingFrame.maxX > $0.frame.minX
                    && movingFrame.minX < $0.frame.maxX
            }
            .sorted { $0.frame.minY < $1.frame.minY }
        let displacement = movingFrame.midY - source.frame.midY

        if displacement > 0 {
            let crossed = candidates.filter { candidate in
                guard candidate.frame.midY > source.frame.midY else { return false }
                let threshold = collisionThreshold(
                    candidate: candidate,
                    insertAfter: true,
                    previousTarget: previousTarget
                )
                return movingFrame.maxY >= candidate.frame.minY + threshold
            }
            guard let target = crossed.last else { return nil }
            return TodoResolvedDropTarget(status: source.status, todoID: target.todoID, insertAfter: true)
        }

        if displacement < 0 {
            let crossed = candidates.filter { candidate in
                guard candidate.frame.midY < source.frame.midY else { return false }
                let threshold = collisionThreshold(
                    candidate: candidate,
                    insertAfter: false,
                    previousTarget: previousTarget
                )
                return movingFrame.minY <= candidate.frame.maxY - threshold
            }
            guard let target = crossed.first else { return nil }
            return TodoResolvedDropTarget(status: source.status, todoID: target.todoID, insertAfter: false)
        }

        return nil
    }

    private static func collisionThreshold(
        candidate: TodoCardDropTarget,
        insertAfter: Bool,
        previousTarget: TodoResolvedDropTarget?
    ) -> CGFloat {
        let isMaintainingCurrentTarget = previousTarget?.status == candidate.status
            && previousTarget?.todoID == candidate.todoID
            && previousTarget?.insertAfter == insertAfter
        return isMaintainingCurrentTarget
            ? -TodoBoardLayout.dragCollisionHysteresis
            : TodoBoardLayout.dragCollisionHysteresis
    }
}


nonisolated enum TodoFriendTagAdapter {
    static func item(_ friend: FriendDTO) -> DPFriendTagItem {
        DPFriendTagItem(
            id: friend.id,
            name: friend.name,
            team: friend.team,
            hasProfilePhoto: friend.hasProfilePhoto,
            profilePhotoVersion: friend.profilePhotoVersion,
            isFamily: friend.isFamily,
            pinOrder: friend.pinOrder
        )
    }

    static func item(_ member: MemberPreviewDTO) -> DPFriendTagItem? {
        guard let id = member.id else { return nil }
        return DPFriendTagItem(
            id: id,
            name: member.name,
            team: member.team,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }
}


struct TodoFormSheet: View {
    let titleKey: String
    let initialDraft: TodoDraft
    let friends: [FriendDTO]
    let preservedTags: [MemberPreviewDTO]
    let initialAttachmentIDs: [AttachmentID]
    let isSaving: Bool
    let maximumHeight: CGFloat?
    let dismissAction: (() -> Void)?
    let savedDismissAction: (() -> Void)?
    let dismissRequest: Int
    let onBusyChange: (Bool) -> Void
    let save: (TodoDraft) async -> Bool

    @ObservedObject var model: TodoViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TodoDraft
    @State private var didSave = false
    @State private var showsDiscardConfirmation = false
    @State private var isDiscarding = false
    @State private var isSubmitting = false
    @StateObject private var attachmentModel: AttachmentPickerModel
    @FocusState private var focusedField: TodoFormField?

    init(
        titleKey: String,
        initialDraft: TodoDraft,
        friends: [FriendDTO],
        model: TodoViewModel,
        targetTodoID: String?,
        existingAttachments: [AttachmentDTO],
        preservedTags: [MemberPreviewDTO] = [],
        isSaving: Bool,
        maximumHeight: CGFloat? = nil,
        dismissAction: (() -> Void)? = nil,
        savedDismissAction: (() -> Void)? = nil,
        dismissRequest: Int = 0,
        onBusyChange: @escaping (Bool) -> Void = { _ in },
        save: @escaping (TodoDraft) async -> Bool
    ) {
        self.titleKey = titleKey
        self.initialDraft = initialDraft
        self.friends = friends
        self.preservedTags = preservedTags
        self.initialAttachmentIDs = existingAttachments.map(\.id)
        self.model = model
        self.isSaving = isSaving
        self.maximumHeight = maximumHeight
        self.dismissAction = dismissAction
        self.savedDismissAction = savedDismissAction
        self.dismissRequest = dismissRequest
        self.onBusyChange = onBusyChange
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

    /// `DPModalOverlay` always measures the height available to the panel; the fallback
    /// keeps the panel bounded when a presenter provides no measurement.
    private var maximumPanelHeight: CGFloat {
        min(maximumHeight.map { $0 * TodoModalLayout.maximumPanelHeightRatio } ?? .infinity, 786)
    }

    var body: some View {
        DPModalPanel(maximumPanelHeight: maximumPanelHeight) {
            formHeader
        } content: {
            formContent
        } footer: {
            formFooter
        }
        .interactiveDismissDisabled(isOperationallyBusy || isDirty)
        .onChange(of: isBusy) { _, value in onBusyChange(value) }
        .onChange(of: dismissRequest) { _, _ in requestDismissal() }
        .onAppear { onBusyChange(isBusy) }
        .onDisappear {
            onBusyChange(false)
            guard !didSave else { return }
            Task { await attachmentModel.discard() }
        }
        .alert(todoLocalized("todo.confirm.discardTitle"), isPresented: $showsDiscardConfirmation) {
            Button(todoLocalized("todo.confirm.discardAction"), role: .destructive) {
                confirmDiscard()
            }
            Button(todoLocalized("common.cancel"), role: .cancel) {}
        } message: {
            Text(todoLocalized("todo.confirm.discardMessage"))
        }
        .todoErrorAlert(model)
    }

    private var formHeader: some View {
        HStack(spacing: DPSpacing.small) {
            Text(todoLocalized(titleKey))
                .font(DPTypography.heading)
                .foregroundStyle(DPColor.textPrimary)
            Spacer()
            Button {
                requestDismissal()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(DPColor.textPrimary)
                    .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
            }
            .buttonStyle(.plain)
            .disabled(isOperationallyBusy)
            .accessibilityLabel(todoLocalized("common.cancel"))
        }
        .padding(.leading, DPSpacing.medium)
        .padding(.trailing, DPSpacing.small)
        .padding(.vertical, DPSpacing.small)
    }

    private var formContent: some View {
        VStack(alignment: .leading, spacing: DPSpacing.large) {
            TodoFormSection(title: todoLocalized("todo.field.status")) {
                HStack(spacing: DPSpacing.small) {
                    ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                        Button {
                            draft.status = status
                        } label: {
                            VStack(spacing: 6) {
                                Image(systemName: status.systemImage)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(todoLocalized(status.shortTitleKey))
                                    .font(DPTypography.caption)
                                    .lineLimit(1)
                            }
                            .foregroundStyle(status.color)
                            .frame(maxWidth: .infinity, minHeight: 62)
                            .background(status.softColor)
                            .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
                            .overlay(
                                RoundedRectangle(cornerRadius: DPRadius.standard)
                                    .stroke(draft.status == status ? status.color : Color.clear, lineWidth: 2)
                            )
                        }
                        .buttonStyle(.plain)
                        .accessibilityAddTraits(draft.status == status ? .isSelected : [])
                    }
                }
            }

            TodoFormSection(title: todoLocalized("todo.field.title")) {
                TextField("", text: $draft.title, prompt: Text(todoLocalized("todo.field.title")))
                    .textInputAutocapitalization(.sentences)
                    .focused($focusedField, equals: .title)
                    .dpInputChrome(
                        isFocused: focusedField == .title,
                        isInvalid: draft.title.count > 50
                    )
                Text(verbatim: "\(draft.title.count)/50")
                    .font(DPTypography.caption)
                    .foregroundStyle(draft.title.count > 50 ? DPColor.danger : DPColor.textMuted)
                    .frame(maxWidth: .infinity, alignment: .trailing)
            }

            TodoFormSection(title: todoLocalized("todo.field.content")) {
                TextEditor(text: $draft.content)
                    .font(DPTypography.body)
                    .foregroundStyle(DPColor.textPrimary)
                    .scrollContentBackground(.hidden)
                    .focused($focusedField, equals: .content)
                    .frame(minHeight: 132)
                    .dpInputChrome(isFocused: focusedField == .content)
                    .overlay(alignment: .topLeading) {
                        if draft.content.isEmpty {
                            Text(todoLocalized("todo.field.content"))
                                .font(DPTypography.body)
                                .foregroundStyle(DPColor.textMuted)
                                .padding(.leading, DPChrome.inputHorizontalPadding + 4)
                                .padding(.top, DPChrome.inputVerticalPadding + 7)
                                .allowsHitTesting(false)
                        }
                    }
            }

            TodoFormSection(title: todoLocalized("todo.field.dueDate")) {
                Toggle(isOn: $draft.hasDueDate) {
                    Label(todoLocalized("todo.field.setDueDate"), systemImage: "calendar")
                        .font(DPTypography.supporting)
                        .foregroundStyle(DPColor.textSecondary)
                }
                .tint(DPColor.accent)
                .frame(minHeight: DPSize.minimumTouchTarget)
                if draft.hasDueDate {
                    DatePicker(
                        todoLocalized("todo.field.dueDate"),
                        selection: $draft.dueDate,
                        displayedComponents: .date
                    )
                    .datePickerStyle(.compact)
                    .font(DPTypography.body)
                    .dpInputChrome()
                }
            }

            if !friends.isEmpty || !preservedTags.isEmpty {
                TodoFormSection(title: todoLocalized("todo.field.tags")) {
                    DPFriendTagSelector(
                        items: friends.map(TodoFriendTagAdapter.item),
                        preservedItems: preservedTags.compactMap(TodoFriendTagAdapter.item),
                        selection: $draft.taggedFriendIDs,
                        disabled: isBusy
                    )
                }
            }

            TodoFormSection(title: todoLocalized("todo.label.attachments")) {
                AttachmentPicker(model: attachmentModel)
                    .padding(DPSpacing.compact)
                    .background(DPColor.backgroundTertiary)
                    .clipShape(RoundedRectangle(cornerRadius: DPRadius.standard))
            }
        }
        .padding(DPSpacing.medium)
    }

    private var formFooter: some View {
        HStack(spacing: DPSpacing.small) {
            Button {
                requestDismissal()
            } label: {
                Text(todoLocalized("common.cancel"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPOutlineButtonStyle())
            .disabled(isOperationallyBusy)

            Button {
                submit()
            } label: {
                Text(todoLocalized("common.save"))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(DPPrimaryButtonStyle())
            .disabled(!draft.canSave || isOperationallyBusy)
        }
        .padding(DPSpacing.compact)
        .safeAreaPadding(.bottom, DPSpacing.extraSmall)
    }

    private func requestDismissal() {
        switch TodoFormDismissalPolicy.action(isDirty: isDirty, isBusy: isOperationallyBusy) {
        case .dismiss:
            dismissForm(saved: false)
        case .confirmDiscard:
            showsDiscardConfirmation = true
        case .ignore:
            break
        }
    }

    private func confirmDiscard() {
        guard !isOperationallyBusy else { return }
        isDiscarding = true
        onBusyChange(true)
        Task {
            let discarded = await attachmentModel.discard()
            isDiscarding = false
            onBusyChange(isBusy)
            if discarded {
                await Task.yield()
                dismissForm(saved: false)
            }
        }
    }

    private func submit() {
        guard TodoFormSubmissionPolicy.canBegin(
            isSubmitting: isSubmitting,
            canSave: draft.canSave,
            isBusy: isOperationallyBusy
        ) else { return }
        isSubmitting = true
        onBusyChange(true)
        Task {
            guard let attachments = await attachmentModel.resultForSave() else {
                isSubmitting = false
                onBusyChange(isBusy)
                return
            }
            var submission = draft
            submission.attachmentSessionId = attachments.attachmentSessionId
            submission.orderedAttachmentIDs = attachments.orderedAttachmentIds
            if await save(submission) {
                didSave = true
                onBusyChange(false)
                await Task.yield()
                dismissForm(saved: true)
            } else {
                isSubmitting = false
                onBusyChange(isBusy)
            }
        }
    }

    private var isDirty: Bool {
        !didSave && TodoFormDismissalPolicy.isDirty(
            initialDraft: initialDraft,
            draft: draft,
            initialAttachmentIDs: initialAttachmentIDs,
            attachmentIDs: attachmentModel.attachments.map(\.id),
            hasAttachmentSession: attachmentModel.attachmentSessionId != nil
        )
    }

    private var isOperationallyBusy: Bool {
        isSubmitting || (!didSave && (isSaving || attachmentModel.isBusy || isDiscarding))
    }

    private var isBusy: Bool {
        isOperationallyBusy
    }

    private func dismissForm(saved: Bool) {
        if saved, let savedDismissAction {
            savedDismissAction()
        } else if !saved, let dismissAction {
            dismissAction()
        } else {
            dismiss()
        }
    }
}

private enum TodoFormField {
    case title
    case content
}

private struct TodoFormSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    init(title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(title)
                .font(DPFont.bold(size: 14, relativeTo: .subheadline))
                .foregroundStyle(DPColor.textSecondary)
            content
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

    var softColor: Color {
        switch self {
        case .todo: DPColor.backgroundTertiary
        case .inProgress: DPColor.warningSoft
        case .done: DPColor.successSoft
        case .unknown: DPColor.backgroundTertiary
        }
    }
}
