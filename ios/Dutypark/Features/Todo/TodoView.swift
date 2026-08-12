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
}

struct TodoView: View {
    let initialTodoID: TodoID?
    let onTodoChanged: () async -> Void
    let onInitialTodoOpened: () -> Void

    @StateObject private var model: TodoViewModel
    @State private var selectedTodo: TodoDTO?
    @State private var showingDetail = false
    @State private var showingCreate = false
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
        .fullScreenCover(isPresented: $showingDetail) {
            if let selectedTodo {
                DPModalOverlay(onDismiss: { showingDetail = false }) { availableSize, dismiss in
                    TodoDetailModal(
                        model: model,
                        todo: selectedTodo,
                        maximumHeight: availableSize.height,
                        onTodoChanged: onTodoChanged,
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
        if draggedTodoID != todo.uuid {
            draggedTodoID = todo.uuid
            dragReferenceCardTargets = cardDropTargets
            dragReferenceColumnTargets = columnDropTargets
            if let frame = cardDropTargets.last(where: { $0.todoID == todo.uuid })?.frame {
                dragPreviewSize = frame.size
                dragGrabOffset = CGSize(
                    width: location.x - frame.midX,
                    height: location.y - frame.midY
                )
            }
        }
        dragLocation = location
        let target = TodoDragTargetResolver.resolve(
            location: location,
            draggedTodoID: todo.uuid,
            cards: dragReferenceCardTargets,
            columns: dragReferenceColumnTargets,
            statuses: statusDropTargets
        )
        withAnimation(.snappy(duration: 0.18, extraBounce: 0)) {
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
                let columnWidth = proxy.size.width * TodoBoardLayout.mobileColumnWidthRatio
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
                                    showingCreate = true
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
                    .padding(.leading, TodoBoardLayout.boardPadding)
                    .padding(.trailing, max(TodoBoardLayout.boardPadding, proxy.size.width - columnWidth - TodoBoardLayout.boardPadding))
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
                .animation(.snappy(duration: 0.18, extraBounce: 0), value: todos.map(\.uuid))
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
        statuses: [TodoStatusDropTarget]
    ) -> TodoResolvedDropTarget? {
        if let status = statuses.last(where: { $0.frame.contains(location) })?.status {
            return TodoResolvedDropTarget(status: status, todoID: nil, insertAfter: false)
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
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: DPSpacing.small) {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: DPSpacing.small) {
                        Text(todo.title)
                            .font(DPTypography.heading)
                            .foregroundStyle(DPColor.textPrimary)
                            .lineLimit(2)
                        Text(todoLocalized(todo.status.titleKey))
                            .font(DPTypography.caption)
                            .foregroundStyle(todo.status.color)
                            .padding(.horizontal, DPSpacing.small)
                            .padding(.vertical, 4)
                            .background(todo.status.softColor, in: Capsule())
                    }
                    Label(todo.createdDate.rawValue.replacingOccurrences(of: "T", with: " "), systemImage: "clock")
                        .font(DPTypography.caption)
                        .foregroundStyle(DPColor.textMuted)
                }
                Spacer(minLength: 0)
                Button(action: dismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(todoLocalized("common.close"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.small)
            .padding(.vertical, DPSpacing.compact)
            .background(DPColor.backgroundModal)

            Divider().overlay(DPColor.borderPrimary)

            ScrollView {
                VStack(alignment: .leading, spacing: DPSpacing.medium) {
                    TodoDetailStatusControl(
                        currentStatus: todo.status,
                        isSaving: model.isSaving
                    ) { status in
                        Task {
                            if await model.move(todo, to: status) {
                                await onTodoChanged()
                                dismiss()
                            }
                        }
                    }

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
                            TodoMemberChips(names: todo.isTagged ? [todo.owner] : todo.tags.map(\.name))
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

            Divider().overlay(DPColor.borderPrimary)

            HStack(spacing: DPSpacing.small) {
                if todo.isTagged {
                    TodoBorderedAction(
                        title: todoLocalized("todo.action.leaveTag"),
                        systemImage: "xmark",
                        color: DPColor.warning,
                        action: { showingLeaveConfirmation = true }
                    )
                } else {
                    TodoBorderedAction(
                        title: todoLocalized("common.edit"),
                        systemImage: "pencil",
                        color: DPColor.accent,
                        action: { showingEdit = true }
                    )
                    .disabled(todo.hasAttachments && model.attachmentsByTodoID[todo.uuid] == nil)
                    TodoBorderedAction(
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
            .safeAreaPadding(.bottom, DPSpacing.extraSmall)
        }
        .background(DPColor.backgroundModal)
        .presentationBackground(DPColor.backgroundModal)
        .presentationCornerRadius(DPRadius.extraLarge)
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

private struct TodoDetailStatusControl: View {
    let currentStatus: TodoStatus
    let isSaving: Bool
    let changeStatus: (TodoStatus) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            Text(todoLocalized("todo.action.status"))
                .font(DPFont.bold(size: 12, relativeTo: .caption))
                .foregroundStyle(DPColor.textMuted)

            HStack(spacing: DPSpacing.small) {
                ForEach(TodoStatus.boardStatuses, id: \.rawValue) { status in
                    let isSelected = status == currentStatus
                    Button {
                        changeStatus(status)
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
                                .stroke(isSelected ? status.color : Color.clear, lineWidth: 2)
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSelected || isSaving)
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                    .accessibilityLabel(todoLocalized(status.titleKey))
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityIdentifier("todo.detail.statusControl")
    }
}

private struct TodoBorderedAction: View {
    let title: String
    let systemImage: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(DPTypography.label)
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

private struct TodoMemberChips: View {
    let names: [String]

    var body: some View {
        TodoFlowLayout(spacing: DPSpacing.small) {
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

private struct TodoFlowLayout: Layout {
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

    private func layout(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, points: [CGPoint]) {
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
        return (CGSize(width: min(usedWidth, availableWidth), height: y + lineHeight), points)
    }
}

struct TodoFormSheet: View {
    let titleKey: String
    let friends: [FriendDTO]
    let isSaving: Bool
    let save: (TodoDraft) async -> Bool

    @ObservedObject var model: TodoViewModel

    @Environment(\.dismiss) private var dismiss
    @State private var draft: TodoDraft
    @State private var didSave = false
    @StateObject private var attachmentModel: AttachmentPickerModel
    @FocusState private var focusedField: TodoFormField?

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
        VStack(spacing: 0) {
            HStack(spacing: DPSpacing.small) {
                Text(todoLocalized(titleKey))
                    .font(DPTypography.heading)
                    .foregroundStyle(DPColor.textPrimary)
                Spacer()
                Button {
                    cancel()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(DPColor.textPrimary)
                        .frame(width: DPSize.minimumTouchTarget, height: DPSize.minimumTouchTarget)
                }
                .buttonStyle(.plain)
                .disabled(isSaving || attachmentModel.isBusy)
                .accessibilityLabel(todoLocalized("common.cancel"))
            }
            .padding(.leading, DPSpacing.medium)
            .padding(.trailing, DPSpacing.small)
            .padding(.vertical, DPSpacing.small)
            .background(DPColor.backgroundModal)

            Divider().overlay(DPColor.borderPrimary)

            ScrollView {
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

                    if !friends.isEmpty {
                        TodoFormSection(title: todoLocalized("todo.field.tags")) {
                            TodoFlowLayout(spacing: DPSpacing.small) {
                                ForEach(friends, id: \.id) { friend in
                                    let selected = draft.taggedFriendIDs.contains(friend.id)
                                    Button {
                                        if selected {
                                            draft.taggedFriendIDs.remove(friend.id)
                                        } else {
                                            draft.taggedFriendIDs.insert(friend.id)
                                        }
                                    } label: {
                                        HStack(spacing: 5) {
                                            Image(systemName: selected ? "checkmark.circle.fill" : "person.crop.circle")
                                            Text(friend.name).lineLimit(1)
                                        }
                                        .font(DPTypography.label)
                                        .foregroundStyle(selected ? DPColor.accent : DPColor.textSecondary)
                                        .padding(.horizontal, 11)
                                        .frame(minHeight: DPSize.minimumTouchTarget)
                                        .background(selected ? DPColor.accentSoft : DPColor.backgroundTertiary, in: Capsule())
                                        .overlay(Capsule().stroke(selected ? DPColor.accentBorder : DPColor.borderPrimary))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(selected ? .isSelected : [])
                                }
                            }
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

            Divider().overlay(DPColor.borderPrimary)

            HStack(spacing: DPSpacing.small) {
                Button(todoLocalized("common.cancel")) {
                    cancel()
                }
                .buttonStyle(DPOutlineButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(isSaving || attachmentModel.isBusy)

                Button(todoLocalized("common.save")) {
                    submit()
                }
                .buttonStyle(DPPrimaryButtonStyle())
                .frame(maxWidth: .infinity)
                .disabled(!draft.canSave || isSaving || attachmentModel.isBusy)
            }
            .padding(DPSpacing.compact)
            .background(DPColor.backgroundModal)
            .safeAreaPadding(.bottom, DPSpacing.extraSmall)
        }
            .background(DPColor.backgroundModal)
            .presentationBackground(DPColor.backgroundModal)
            .presentationCornerRadius(DPRadius.extraLarge)
            .interactiveDismissDisabled(isSaving || attachmentModel.isBusy || attachmentModel.attachmentSessionId != nil)
            .onDisappear {
                guard !didSave else { return }
                Task { await attachmentModel.discard() }
            }
            .todoErrorAlert(model)
    }

    private func cancel() {
        Task {
            if await attachmentModel.discard() {
                dismiss()
            }
        }
    }

    private func submit() {
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
