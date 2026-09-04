import Foundation
import Testing
@testable import Dutypark

@MainActor
struct TodoCacheIntegrityTests {
    @Test
    func calendarDetailStatusMoveDoesNotReplaceTheFullBoardCache() async {
        let first = makeTodo(title: "First", status: .todo)
        let second = makeTodo(title: "Second", status: .inProgress)
        let cachedBoard = makeBoard(todo: [first], inProgress: [second])
        let moved = makeTodo(id: first.uuid, title: first.title, status: .done)
        let cache = TodoCacheIntegrityCache(board: cachedBoard)
        let repository = TodoCacheIntegrityRepository(
            statusResponse: moved,
            boardError: .transport
        )
        let model = TodoViewModel(
            repository: repository,
            cache: cache,
            recoveryDelays: []
        )

        // Calendar details bind only the account/session. They intentionally do
        // not load the full Todo board before allowing an online status move.
        model.configureSession(accountID: 42, availability: .online)

        #expect(await model.move(first, to: .done))
        #expect(model.board?.todo.isEmpty == true)
        #expect(model.board?.done.map(\.uuid) == [first.uuid])

        // A failed refresh falls back to the durable board. The unrelated card
        // must still be present instead of being erased by the detail mutation.
        await model.refresh()

        #expect(model.isOffline)
        #expect(model.isShowingCachedData)
        #expect(model.board == cachedBoard)
    }
}

private actor TodoCacheIntegrityRepository: TodoRepository {
    let statusResponse: TodoDTO
    let boardError: APIError

    init(statusResponse: TodoDTO, boardError: APIError) {
        self.statusResponse = statusResponse
        self.boardError = boardError
    }

    func fetchBoard() async throws -> TodoBoardDTO { throw boardError }
    func fetchFriends() async throws -> [FriendDTO] { [] }
    func fetchAttachments(todoID: TodoID) async throws -> [AttachmentDTO] { [] }
    func create(_ request: TodoRequest) async throws -> TodoDTO { throw boardError }
    func update(id: TodoID, request: TodoRequest) async throws -> TodoDTO { throw boardError }
    func delete(id: TodoID) async throws { throw boardError }
    func complete(id: TodoID) async throws -> TodoDTO { statusResponse }
    func reopen(id: TodoID) async throws -> TodoDTO { statusResponse }
    func changeStatus(id: TodoID, request: TodoStatusChangeRequest) async throws -> TodoDTO {
        statusResponse
    }
    func updatePositions(_ request: TodoPositionUpdateRequest) async throws { throw boardError }
    func leaveTag(id: TodoID) async throws { throw boardError }
}

private actor TodoCacheIntegrityCache: OfflineCacheProviding {
    private var board: TodoBoardDTO?

    init(board: TodoBoardDTO) {
        self.board = board
    }

    func saveAccount(_ snapshot: OfflineAccountSnapshot) async throws {}
    func saveAccount(member: LoginMember, friends: [FriendDTO], dDays: [DDayDTO], now: Date) async throws {}
    func loadAccount(memberID: MemberID) async -> OfflineAccountSnapshot? { nil }
    func saveMonth(_ snapshot: OfflineMonthSnapshot) async throws {}
    func loadMonth(accountID: MemberID, key: OfflineMonthKey) async -> OfflineMonthSnapshot? { nil }
    func loadCachedMonths(accountID: MemberID, around current: OfflineMonthKey) async -> [OfflineMonthSnapshot] { [] }
    func saveTodoBoard(accountID: MemberID, board: TodoBoardDTO, now: Date) async throws {
        self.board = board
    }
    func loadTodoBoard(accountID: MemberID) async -> TodoBoardDTO? { board }
    func searchSchedules(accountID: MemberID, query: String, keys: [OfflineMonthKey]?) async -> [ScheduleSearchResultDTO] { [] }
    func purge(accountID: MemberID) async throws {}
}

private func makeTodo(
    id: TodoID = UUID(),
    title: String,
    status: TodoStatus
) -> TodoDTO {
    TodoDTO(
        id: id.uuidString,
        title: title,
        content: "Details",
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-12T10:00:00"),
        completedDate: nil,
        dueDate: nil,
        isOverdue: false,
        isTagged: false,
        owner: "Me",
        taggedByMember: nil,
        tags: [],
        hasAttachments: false
    )
}

private func makeBoard(todo: [TodoDTO], inProgress: [TodoDTO]) -> TodoBoardDTO {
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
