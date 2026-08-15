import Foundation
import Testing
@testable import Dutypark

@MainActor
struct TodoViewModelTests {
    @Test
    func todoDraftSortsTaggedFriendIDsForStablePayloads() {
        var draft = TodoDraft()
        draft.title = "Tagged task"
        draft.taggedFriendIDs = Set<MemberID>([30, 10, 20])

        #expect(draft.request().tagFriendIds == [10, 20, 30])
    }

    @Test
    func activeDetailEditShowsAndCanDeselectAStaleTag() {
        let staleTag = MemberPreviewDTO(
            id: 42,
            name: "Former friend",
            teamId: nil,
            team: "Previous team",
            hasProfilePhoto: false,
            profilePhotoVersion: 0
        )
        let preservedItems = [staleTag].compactMap(TodoFriendTagAdapter.item)
        var selection: Set<MemberID> = [42]

        #expect(DPFriendTagSelectionLogic.mergedItems(
            items: [],
            preservedItems: preservedItems,
            selection: selection
        ).map(\.id) == [42])

        selection.remove(42)

        #expect(DPFriendTagSelectionLogic.mergedItems(
            items: [],
            preservedItems: preservedItems,
            selection: selection
        ).isEmpty)
    }

    @Test
    func todoFormRejectsDuplicateSubmitWhileFirstSaveIsInFlight() {
        #expect(TodoFormSubmissionPolicy.canBegin(
            isSubmitting: false,
            canSave: true,
            isBusy: false
        ))
        #expect(!TodoFormSubmissionPolicy.canBegin(
            isSubmitting: true,
            canSave: true,
            isBusy: false
        ))
    }

    @Test
    func calendarQuickAddUsesInProgressWithoutDueDateAsItsCleanBaseline() {
        let draft = TodoDraft(status: .inProgress)

        #expect(draft.status == .inProgress)
        #expect(!draft.hasDueDate)
        #expect(draft.request().dueDate == nil)
        #expect(!TodoFormDismissalPolicy.isDirty(
            initialDraft: draft,
            draft: draft,
            initialAttachmentIDs: [],
            attachmentIDs: [],
            hasAttachmentSession: false
        ))
    }

    @Test
    func todoFormDismissalPolicyConfirmsDraftTagsAndAttachmentChanges() {
        let initial = TodoDraft(status: .inProgress)
        var tagged = initial
        tagged.taggedFriendIDs = [42]

        #expect(TodoFormDismissalPolicy.isDirty(
            initialDraft: initial,
            draft: tagged,
            initialAttachmentIDs: [],
            attachmentIDs: [],
            hasAttachmentSession: false
        ))
        #expect(TodoFormDismissalPolicy.isDirty(
            initialDraft: initial,
            draft: initial,
            initialAttachmentIDs: [],
            attachmentIDs: [UUID()],
            hasAttachmentSession: false
        ))
        #expect(TodoFormDismissalPolicy.isDirty(
            initialDraft: initial,
            draft: initial,
            initialAttachmentIDs: [],
            attachmentIDs: [],
            hasAttachmentSession: true
        ))
        #expect(TodoFormDismissalPolicy.action(isDirty: false, isBusy: false) == .dismiss)
        #expect(TodoFormDismissalPolicy.action(isDirty: true, isBusy: false) == .confirmDiscard)
        #expect(TodoFormDismissalPolicy.action(isDirty: true, isBusy: true) == .ignore)
    }

    @Test
    func calendarQuickAddDoesNotRefetchTodoBoardAfterSuccessfulPost() async {
        let created = makeTodo(status: .inProgress)
        let repository = FakeTodoRepository(board: makeBoard(inProgress: [created]))
        let model = TodoViewModel(repository: repository)
        var draft = TodoDraft(status: .inProgress)
        draft.title = "Quick task"

        let succeeded = await model.create(draft: draft, refreshBoard: false)
        let request = await repository.createRequest
        let fetchCount = await repository.fetchBoardCount

        #expect(succeeded)
        #expect(request?.status == .inProgress)
        #expect(request?.dueDate == nil)
        #expect(fetchCount == 0)
    }

    @Test
    func mobileBoardMatchesWebColumnGeometry() {
        #expect(TodoBoardLayout.mobileColumnWidthRatio == 0.62)
        #expect(TodoBoardLayout.boardPadding == 8)
        #expect(TodoBoardLayout.columnGap == 10)
        #expect(TodoBoardLayout.columnRadius == 12)
        #expect(TodoBoardLayout.cardRadius == 14)
        #expect(TodoBoardLayout.dragLongPressDuration == 0.35)
        #expect(TodoBoardLayout.dragLongPressMaximumDistance == 10)
        #expect(TodoBoardLayout.dragCollisionHysteresis == 2)
        #expect(TodoBoardLayout.dragPushAnimationDuration == 0.1)

        let miniColumnWidth = TodoBoardLayout.mobileColumnWidth(in: 375)
        let proColumnWidth = TodoBoardLayout.mobileColumnWidth(in: 402)
        #expect(miniColumnWidth == 232.5)
        #expect(proColumnWidth == 249.24)

        #expect(TodoBoardLayout.centeredColumnInset(containerWidth: 375, columnWidth: miniColumnWidth) == 71.25)
        #expect(TodoBoardLayout.centeredColumnInset(containerWidth: 402, columnWidth: proColumnWidth) == 76.38)
        #expect(TodoBoardLayout.adjacentColumnPeekWidth(containerWidth: 375, columnWidth: miniColumnWidth) == 61.25)
        #expect(TodoBoardLayout.adjacentColumnPeekWidth(containerWidth: 402, columnWidth: proColumnWidth) == 66.38)
    }

    @Test
    func narrowBoardKeepsMinimumHorizontalPadding() {
        #expect(TodoBoardLayout.centeredColumnInset(containerWidth: 100, columnWidth: 96) == 8)
        #expect(TodoBoardLayout.adjacentColumnPeekWidth(containerWidth: 100, columnWidth: 96) == 0)
    }

    @Test(arguments: [
        (false, false, false),
        (false, true, false),
        (true, false, false),
        (true, true, true)
    ])
    func cardDragStartsOnlyAfterLongPressAndDragValueExist(
        didLongPress: Bool,
        hasDragValue: Bool,
        expected: Bool
    ) {
        #expect(TodoCardDragActivation.shouldReorder(
            didLongPress: didLongPress,
            hasDragValue: hasDragValue
        ) == expected)
    }

    @Test
    func longPressedCardDoesNotMoveWhileStillInsideItsSourceFrame() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let otherID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 100, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: otherID,
                status: .todo,
                frame: CGRect(x: 10, y: 190, width: 200, height: 80)
            )
        ]

        let target = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 190, y: 104),
            draggedTodoID: sourceID,
            cards: cards,
            columns: [TodoColumnDropTarget(
                status: .todo,
                frame: CGRect(x: 0, y: 80, width: 220, height: 400)
            )],
            statuses: []
        )

        #expect(target == nil)
    }

    @Test
    func floatingCardEdgesPushDifferentHeightCardsAtFirstOverlap() {
        let previousID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let nextID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cards = [
            TodoCardDropTarget(
                todoID: previousID,
                status: .todo,
                frame: CGRect(x: 10, y: 20, width: 200, height: 70)
            ),
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 100, width: 200, height: 120)
            ),
            TodoCardDropTarget(
                todoID: nextID,
                status: .todo,
                frame: CGRect(x: 10, y: 230, width: 200, height: 54)
            )
        ]
        let columns = [TodoColumnDropTarget(
            status: .todo,
            frame: CGRect(x: 0, y: 0, width: 220, height: 500)
        )]

        let upwardTarget = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 195, y: 148),
            draggedTodoID: sourceID,
            cards: cards,
            columns: columns,
            statuses: [],
            movingFrame: CGRect(x: 10, y: 88, width: 200, height: 120)
        )
        let downwardTarget = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 195, y: 172),
            draggedTodoID: sourceID,
            cards: cards,
            columns: columns,
            statuses: [],
            movingFrame: CGRect(x: 10, y: 112, width: 200, height: 120)
        )

        #expect(upwardTarget == TodoResolvedDropTarget(
            status: .todo,
            todoID: previousID,
            insertAfter: false
        ))
        #expect(downwardTarget == TodoResolvedDropTarget(
            status: .todo,
            todoID: nextID,
            insertAfter: true
        ))
    }

    @Test
    func edgeCollisionCatchesUpAcrossCardsAndIgnoresOtherColumns() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let firstID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let secondID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let otherColumnID = UUID(uuidString: "44444444-4444-4444-4444-444444444444")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 20, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: firstID,
                status: .todo,
                frame: CGRect(x: 10, y: 110, width: 200, height: 50)
            ),
            TodoCardDropTarget(
                todoID: secondID,
                status: .todo,
                frame: CGRect(x: 10, y: 170, width: 200, height: 100)
            ),
            TodoCardDropTarget(
                todoID: otherColumnID,
                status: .todo,
                frame: CGRect(x: 240, y: 190, width: 200, height: 70)
            )
        ]

        let target = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 195, y: 170),
            draggedTodoID: sourceID,
            cards: cards,
            columns: [TodoColumnDropTarget(
                status: .todo,
                frame: CGRect(x: 0, y: 0, width: 220, height: 500)
            )],
            statuses: [],
            movingFrame: CGRect(x: 10, y: 130, width: 200, height: 80)
        )

        #expect(target == TodoResolvedDropTarget(
            status: .todo,
            todoID: secondID,
            insertAfter: true
        ))
    }

    @Test
    func crossColumnTargetWinsWhenPreviewStillPartlyOverlapsSourceColumn() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let sameColumnID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let nextColumnID = UUID(uuidString: "33333333-3333-3333-3333-333333333333")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 20, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: sameColumnID,
                status: .todo,
                frame: CGRect(x: 10, y: 110, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: nextColumnID,
                status: .inProgress,
                frame: CGRect(x: 230, y: 110, width: 200, height: 80)
            )
        ]

        let target = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 250, y: 130),
            draggedTodoID: sourceID,
            cards: cards,
            columns: [TodoColumnDropTarget(
                status: .inProgress,
                frame: CGRect(x: 220, y: 0, width: 220, height: 500)
            )],
            statuses: [],
            movingFrame: CGRect(x: 150, y: 90, width: 200, height: 80)
        )

        #expect(target == TodoResolvedDropTarget(
            status: .inProgress,
            todoID: nextColumnID,
            insertAfter: false
        ))
    }

    @Test
    func edgeCollisionKeepsPreviousTargetWithinTwoPointHysteresis() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let targetID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 20, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: targetID,
                status: .todo,
                frame: CGRect(x: 10, y: 110, width: 200, height: 80)
            )
        ]
        let previousTarget = TodoResolvedDropTarget(
            status: .todo,
            todoID: targetID,
            insertAfter: true
        )

        let maintained = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 195, y: 68),
            draggedTodoID: sourceID,
            cards: cards,
            columns: [TodoColumnDropTarget(
                status: .todo,
                frame: CGRect(x: 0, y: 0, width: 220, height: 400)
            )],
            statuses: [],
            movingFrame: CGRect(x: 10, y: 29, width: 200, height: 80),
            previousTarget: previousTarget
        )
        let released = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 195, y: 66),
            draggedTodoID: sourceID,
            cards: cards,
            columns: [TodoColumnDropTarget(
                status: .todo,
                frame: CGRect(x: 0, y: 0, width: 220, height: 400)
            )],
            statuses: [],
            movingFrame: CGRect(x: 10, y: 27, width: 200, height: 80),
            previousTarget: previousTarget
        )

        #expect(maintained == previousTarget)
        #expect(released == nil)
    }

    @Test
    func cardDragMapsCardGapsAndColumnBottomToStableDropTargets() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let otherID = UUID(uuidString: "22222222-2222-2222-2222-222222222222")!
        let cards = [
            TodoCardDropTarget(
                todoID: sourceID,
                status: .todo,
                frame: CGRect(x: 10, y: 100, width: 200, height: 80)
            ),
            TodoCardDropTarget(
                todoID: otherID,
                status: .todo,
                frame: CGRect(x: 10, y: 190, width: 200, height: 80)
            )
        ]
        let columns = [TodoColumnDropTarget(
            status: .todo,
            frame: CGRect(x: 0, y: 80, width: 220, height: 400)
        )]

        let gapTarget = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 100, y: 185),
            draggedTodoID: sourceID,
            cards: cards,
            columns: columns,
            statuses: []
        )
        let bottomTarget = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 100, y: 350),
            draggedTodoID: sourceID,
            cards: cards,
            columns: columns,
            statuses: []
        )

        #expect(gapTarget == TodoResolvedDropTarget(
            status: .todo,
            todoID: otherID,
            insertAfter: false
        ))
        #expect(bottomTarget == TodoResolvedDropTarget(
            status: .todo,
            todoID: nil,
            insertAfter: false
        ))
    }

    @Test
    func statusSelectorTakesPriorityAsCrossColumnDropTarget() {
        let sourceID = UUID(uuidString: "11111111-1111-1111-1111-111111111111")!
        let target = TodoDragTargetResolver.resolve(
            location: CGPoint(x: 250, y: 24),
            draggedTodoID: sourceID,
            cards: [],
            columns: [],
            statuses: [TodoStatusDropTarget(
                status: .done,
                frame: CGRect(x: 220, y: 0, width: 100, height: 48)
            )]
        )

        #expect(target == TodoResolvedDropTarget(
            status: .done,
            todoID: nil,
            insertAfter: false
        ))
    }

    @Test
    func interactiveDragProjectionMovesTheFullCardAndPushesAdjacentItemsBeforeDrop() {
        let first = makeTodo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "First"
        )
        let moving = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Moving"
        )
        let last = makeTodo(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            title: "Last"
        )
        let original: [TodoStatus: [TodoDTO]] = [
            .todo: [first, moving, last],
            .inProgress: [],
            .done: []
        ]

        let projected = TodoDragProjection.columns(
            projecting: TodoDragPlacement(
                todoID: moving.uuid,
                destinationStatus: .todo,
                targetTodoID: last.uuid,
                insertAfter: true
            ),
            from: original
        )

        #expect(projected[.todo]?.map(\.uuid) == [first.uuid, last.uuid, moving.uuid])
        #expect(original[.todo]?.map(\.uuid) == [first.uuid, moving.uuid, last.uuid])

        let crossColumnProjection = TodoDragProjection.columns(
            projecting: TodoDragPlacement(
                todoID: moving.uuid,
                destinationStatus: .inProgress,
                targetTodoID: nil,
                insertAfter: false
            ),
            from: original
        )
        #expect(crossColumnProjection == original)
    }

    @Test
    func todoCatalogResolvesFeatureAndCommonKeysInEverySupportedLocale() {
        let keys = [
            "todo.action.add",
            "todo.action.complete",
            "todo.action.delete",
            "todo.action.leaveTag",
            "todo.action.reopen",
            "todo.confirm.discardTitle",
            "todo.confirm.discardMessage",
            "todo.confirm.discardAction",
            "todo.drag.dropHere",
            "todo.drag.hint",
            "todo.error.load",
            "todo.help.open",
            "todo.help.title",
            "todo.help.kanban.body",
            "todo.help.todo.body",
            "todo.help.progress.body",
            "todo.help.done.body",
            "todo.help.tips.title",
            "todo.help.tip.1",
            "todo.help.tip.5",
            "common.close",
            "common.edit",
            "common.save"
        ]
        let locales = ["ko", "en"]

        for localeIdentifier in locales {
            for key in keys {
                #expect(
                    todoLocalized(key, locale: Locale(identifier: localeIdentifier)) != key,
                    "\(key) was not resolved for \(localeIdentifier)"
                )
            }
        }
    }

    @Test
    func detailModalFitsShortContentAndCapsLongContentForIPhone13Mini() {
        let availableOverlayHeight: CGFloat = 780
        let maximumPanelHeight = availableOverlayHeight * TodoModalLayout.maximumPanelHeightRatio
        let fixedChromeHeight: CGFloat = 176

        #expect(TodoModalLayout.maximumPanelHeightRatio == 0.9)
        #expect(TodoModalLayout.bodyHeight(
            contentHeight: 148,
            maximumPanelHeight: maximumPanelHeight,
            fixedChromeHeight: fixedChromeHeight
        ) == 148)
        #expect(TodoModalLayout.bodyHeight(
            contentHeight: 900,
            maximumPanelHeight: maximumPanelHeight,
            fixedChromeHeight: fixedChromeHeight
        ) == 526)
    }

    @Test
    func destructiveConfirmationMapsDeleteAndLeaveActions() {
        #expect(TodoDestructiveConfirmation.delete.titleKey == "todo.confirm.deleteTitle")
        #expect(TodoDestructiveConfirmation.delete.messageKey == "todo.confirm.deleteMessage")
        #expect(TodoDestructiveConfirmation.delete.actionKey == "todo.action.delete")
        #expect(TodoDestructiveConfirmation.leaveTag.titleKey == "todo.confirm.leaveTitle")
        #expect(TodoDestructiveConfirmation.leaveTag.messageKey == "todo.confirm.leaveMessage")
        #expect(TodoDestructiveConfirmation.leaveTag.actionKey == "todo.action.leaveTag")
    }

    @Test
    func loadSelectsFirstNonemptyColumnAndCountsTaggedTodos() async {
        let own = makeTodo(title: "Own", status: .todo)
        let tagged = makeTodo(title: "Shared", status: .todo, isTagged: true)
        let repository = FakeTodoRepository(board: makeBoard(todo: [own, tagged]))
        let model = TodoViewModel(repository: repository)

        await model.load()

        #expect(model.selectedStatus == .todo)
        #expect(model.count(for: .todo) == 2)
        #expect(model.selectedTodos.map(\.title) == ["Own", "Shared"])
    }

    @Test
    func taggedTodoCanMoveStatusWithoutOwnerEdit() async {
        let todo = makeTodo(status: .todo, isTagged: true)
        let repository = FakeTodoRepository(board: makeBoard(todo: [todo]))
        let model = TodoViewModel(repository: repository)

        let succeeded = await model.move(todo, to: .inProgress)
        let change = await repository.statusChange

        #expect(succeeded)
        #expect(change?.id == UUID(uuidString: todo.id))
        #expect(change?.request.status == .inProgress)
        #expect(change?.request.orderedIds.isEmpty == true)
    }

    @Test(arguments: [
        (TodoStatus.todo, TodoStatus.inProgress),
        (TodoStatus.inProgress, TodoStatus.todo)
    ])
    func detailStatusControlMovesDirectlyBetweenActiveColumns(
        source: TodoStatus,
        destination: TodoStatus
    ) async {
        let todo = makeTodo(status: source)
        let repository = FakeTodoRepository(
            board: source == .todo
                ? makeBoard(todo: [todo])
                : makeBoard(inProgress: [todo])
        )
        let model = TodoViewModel(repository: repository)

        let succeeded = await model.move(todo, to: destination)
        let change = await repository.statusChange

        #expect(succeeded)
        #expect(change?.id == todo.uuid)
        #expect(change?.request.status == destination)
        #expect(change?.request.orderedIds.isEmpty == true)
    }

    @Test
    func notificationTodoSelectsItsColumnForPresentation() async {
        let todo = makeTodo(status: .inProgress)
        let repository = FakeTodoRepository(board: makeBoard(inProgress: [todo]))
        let model = TodoViewModel(repository: repository)

        await model.load()
        let opened = model.open(todoID: todo.uuid)

        #expect(opened?.id == todo.id)
        #expect(model.selectedStatus == .inProgress)
    }

    @Test
    func updatePreservesEveryExistingAttachmentID() async {
        let todo = makeTodo(hasAttachments: true)
        let first = makeAttachment(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let second = makeAttachment(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!)
        let repository = FakeTodoRepository(
            board: makeBoard(todo: [todo]),
            attachments: [first, second]
        )
        let model = TodoViewModel(repository: repository)

        await model.loadAttachments(for: todo)
        var draft = TodoDraft(todo: todo)
        draft.title = "Updated"
        draft.orderedAttachmentIDs = [first.id, second.id]
        let succeeded = await model.update(todo: todo, draft: draft)
        let update = await repository.updateRequest

        #expect(succeeded)
        #expect(update?.request.orderedAttachmentIds == [first.id, second.id])
    }

    @Test
    func detailAttachmentPreloadCachesFilesForEditing() async {
        let todo = makeTodo(hasAttachments: true)
        let attachment = makeAttachment(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!)
        let repository = FakeTodoRepository(
            board: makeBoard(todo: [todo]),
            attachments: [attachment]
        )
        let model = TodoViewModel(repository: repository)

        await model.loadAttachments(for: todo)

        #expect(model.attachmentsByTodoID[todo.uuid] == [attachment])
        #expect(model.errorKey == nil)
    }

    @Test
    func failedDetailAttachmentPreloadKeepsEditingLockedAndReportsError() async {
        let todo = makeTodo(hasAttachments: true)
        let repository = FakeTodoRepository(
            board: makeBoard(todo: [todo]),
            shouldFailAttachmentFetch: true
        )
        let model = TodoViewModel(repository: repository)

        await model.loadAttachments(for: todo)

        #expect(model.attachmentsByTodoID[todo.uuid] == nil)
        #expect(model.errorKey == "todo.error.attachments")
    }

    @Test
    func sameColumnMoveSendsTheCompleteViewerOrder() async {
        let first = makeTodo(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "First")
        let tagged = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Shared",
            isTagged: true
        )
        let repository = FakeTodoRepository(board: makeBoard(todo: [first, tagged]))
        let model = TodoViewModel(repository: repository)

        await model.load()

        await model.moveWithinSelectedColumn(tagged, offset: -1)
        let reorder = await repository.positionRequest

        #expect(reorder?.status == .todo)
        #expect(reorder?.orderedIds == [tagged.uuid, first.uuid])
    }

    @Test
    func cardDropOptimisticallyReordersOwnedAndTaggedTodosInOneViewerOrder() async {
        let first = makeTodo(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "First")
        let tagged = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Shared",
            isTagged: true
        )
        let repository = FakeTodoRepository(board: makeBoard(todo: [first, tagged]))
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(
            todoID: tagged.uuid,
            into: .todo,
            relativeTo: first.uuid,
            insertAfter: false
        )
        let request = await repository.positionRequest

        #expect(succeeded)
        #expect(model.todos(for: .todo).map(\.uuid) == [tagged.uuid, first.uuid])
        #expect(request == TodoPositionUpdateRequest(status: .todo, orderedIds: [tagged.uuid, first.uuid]))
    }

    @Test
    func crossColumnDropSendsTheCompleteDestinationOrderAndUpdatesStatus() async {
        let moving = makeTodo(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            title: "Shared",
            status: .todo,
            isTagged: true
        )
        let existing = makeTodo(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            title: "Existing",
            status: .inProgress
        )
        let repository = FakeTodoRepository(board: makeBoard(todo: [moving], inProgress: [existing]))
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(
            todoID: moving.uuid,
            into: .inProgress,
            relativeTo: existing.uuid,
            insertAfter: true
        )
        let change = await repository.statusChange

        #expect(succeeded)
        #expect(model.todos(for: .todo).isEmpty)
        #expect(model.todos(for: .inProgress).map(\.uuid) == [existing.uuid, moving.uuid])
        #expect(model.todos(for: .inProgress).last?.status == .inProgress)
        #expect(change?.id == moving.uuid)
        #expect(change?.request == TodoStatusChangeRequest(
            status: .inProgress,
            orderedIds: [existing.uuid, moving.uuid]
        ))
    }

    @Test
    func failedDropRestoresTheOriginalBoardAndExposesReorderError() async {
        let first = makeTodo(id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!, title: "First")
        let second = makeTodo(id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!, title: "Second")
        let original = makeBoard(todo: [first, second])
        let repository = FakeTodoRepository(board: original, shouldFailPositionUpdate: true)
        let model = TodoViewModel(repository: repository)
        await model.load()

        let succeeded = await model.drop(
            todoID: second.uuid,
            into: .todo,
            relativeTo: first.uuid,
            insertAfter: false
        )

        #expect(!succeeded)
        #expect(model.board == original)
        #expect(model.errorKey == "todo.error.reorder")
    }
}

private actor FakeTodoRepository: TodoRepository {
    var board: TodoBoardDTO
    let attachments: [AttachmentDTO]
    var updateRequest: (id: TodoID, request: TodoRequest)?
    var statusChange: (id: TodoID, request: TodoStatusChangeRequest)?
    var positionRequest: TodoPositionUpdateRequest?
    var createRequest: TodoRequest?
    var fetchBoardCount = 0
    let shouldFailPositionUpdate: Bool
    let shouldFailAttachmentFetch: Bool

    init(
        board: TodoBoardDTO,
        attachments: [AttachmentDTO] = [],
        shouldFailPositionUpdate: Bool = false,
        shouldFailAttachmentFetch: Bool = false
    ) {
        self.board = board
        self.attachments = attachments
        self.shouldFailPositionUpdate = shouldFailPositionUpdate
        self.shouldFailAttachmentFetch = shouldFailAttachmentFetch
    }

    func fetchBoard() async throws -> TodoBoardDTO {
        fetchBoardCount += 1
        return board
    }
    func fetchFriends() async throws -> [FriendDTO] { [] }
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] {
        if shouldFailAttachmentFetch {
            throw CocoaError(.fileReadUnknown)
        }
        return attachments
    }
    func create(_ request: TodoRequest) async throws -> TodoDTO {
        createRequest = request
        guard let todo = (board.todo + board.inProgress + board.done).first else {
            throw CocoaError(.fileNoSuchFile)
        }
        return todo
    }

    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO {
        updateRequest = (id, request)
        return board.todo[0]
    }

    func delete(id: TodoID) async throws {}
    func complete(id: TodoID) async throws -> TodoDTO { board.todo[0] }
    func reopen(id: TodoID) async throws -> TodoDTO { board.todo[0] }

    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) async throws -> TodoDTO {
        statusChange = (id, request)
        return try todo(id: id)
    }

    func updatePositions(_ request: TodoPositionUpdateRequest) async throws {
        if shouldFailPositionUpdate {
            throw CocoaError(.fileWriteUnknown)
        }
        positionRequest = request
    }

    func leaveTag(id: TodoID) async throws {}

    private func todo(id: TodoID) throws -> TodoDTO {
        guard let todo = (board.todo + board.inProgress + board.done)
            .first(where: { $0.uuid == id })
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        return todo
    }
}

private func makeTodo(
    id: UUID = UUID(),
    title: String = "Todo",
    status: TodoStatus = .todo,
    isTagged: Bool = false,
    hasAttachments: Bool = false
) -> TodoDTO {
    TodoDTO(
        id: id.uuidString,
        title: title,
        content: "Details",
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
        completedDate: nil,
        dueDate: DateOnly(rawValue: "2026-08-20"),
        isOverdue: false,
        isTagged: isTagged,
        owner: isTagged ? "Owner" : "Me",
        taggedByMember: nil,
        tags: [],
        hasAttachments: hasAttachments
    )
}

private func makeBoard(todo: [TodoDTO] = [], inProgress: [TodoDTO] = []) -> TodoBoardDTO {
    TodoBoardDTO(
        todo: todo,
        inProgress: inProgress,
        done: [],
        counts: TodoCountsDTO(
            todo: todo.count,
            inProgress: inProgress.count,
            done: 0,
            total: todo.count + inProgress.count
        )
    )
}

private func makeAttachment(id: UUID) -> AttachmentDTO {
    AttachmentDTO(
        id: id,
        contextType: .todo,
        contextId: UUID().uuidString,
        originalFilename: "file.pdf",
        contentType: "application/pdf",
        size: 100,
        hasThumbnail: false,
        thumbnailUrl: nil,
        orderIndex: 0,
        createdAt: "2026-08-12T10:00:00+09:00",
        createdBy: 1
    )
}
