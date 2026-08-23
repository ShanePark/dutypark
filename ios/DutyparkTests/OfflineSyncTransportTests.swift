import Foundation
import XCTest
@testable import Dutypark

@MainActor
final class OfflineSyncTransportTests: XCTestCase {
    private let baseURL = URL(string: "https://dutypark.test/api/")!

    override func tearDown() {
        OfflineSyncURLProtocol.handler = nil
        super.tearDown()
    }

    func testScheduleCrossingMonthFetchesBothMonthsAndDeduplicatesSameID() async throws {
        let recorder = OfflineSyncRequestRecorder()
        let request = makeScheduleRequest(
            startDateTime: "2026-08-31T23:00:00",
            endDateTime: "2026-09-01T01:00:00"
        )
        let existing = makeScheduleDTO(
            id: UUID(),
            startDateTime: request.startDateTime.rawValue,
            endDateTime: request.endDateTime.rawValue
        )

        OfflineSyncURLProtocol.handler = { request in
            recorder.append(request)
            guard let url = request.url else {
                throw OfflineSyncURLProtocolError.invalidURL
            }
            let month = URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            )?.queryItems?.first(where: { $0.name == "month" })?.value
            let schedules: [[ScheduleDTO]] = switch month {
            case "8", "9": [[existing]]
            default: []
            }
            return try Self.response(for: request, encoding: schedules)
        }

        let transport = makeTransport()
        let matched = try await transport.scheduleAlreadyExists(
            accountID: 42,
            request: request
        )

        XCTAssertTrue(matched)
        let requests = recorder.requests
        XCTAssertEqual(requests.count, 2)
        XCTAssertEqual(requests.map { $0.httpMethod }, ["GET", "GET"])
        XCTAssertEqual(
            requests.compactMap { Self.queryItem(named: "month", in: $0) },
            ["8", "9"]
        )
        XCTAssertTrue(requests.allSatisfy {
            Self.queryItem(named: "memberId", in: $0) == "42"
        })
    }

    func testScheduleWithTwoDifferentEquivalentCandidatesThrowsMultipleCandidates() async throws {
        let recorder = OfflineSyncRequestRecorder()
        let request = makeScheduleRequest(
            startDateTime: "2026-08-31T23:00:00",
            endDateTime: "2026-09-01T01:00:00"
        )
        let first = makeScheduleDTO(
            id: UUID(),
            startDateTime: request.startDateTime.rawValue,
            endDateTime: request.endDateTime.rawValue
        )
        let second = makeScheduleDTO(
            id: UUID(),
            startDateTime: request.startDateTime.rawValue,
            endDateTime: request.endDateTime.rawValue
        )

        OfflineSyncURLProtocol.handler = { request in
            recorder.append(request)
            let schedules: [[ScheduleDTO]] = [[first, second]]
            return try Self.response(for: request, encoding: schedules)
        }

        do {
            _ = try await makeTransport().scheduleAlreadyExists(
                accountID: 42,
                request: request
            )
            XCTFail("Expected multiple equivalent schedule candidates to be rejected")
        } catch OfflineCreateDedupeError.multipleCandidates {
            // Expected: two different server IDs cannot safely identify one
            // ambiguous offline create.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.requests.count, 2)
    }

    func testTodoBoardFlattensThreeColumnsAndDeduplicatesSameID() async throws {
        let recorder = OfflineSyncRequestRecorder()
        let request = makeTodoRequest(
            title: "Offline todo",
            content: "Description",
            status: .done,
            dueDate: "2026-08-12"
        )
        let existing = makeTodoDTO(
            id: "todo-duplicate",
            title: request.title,
            content: request.content,
            status: .done,
            dueDate: request.dueDate?.rawValue
        )
        let unrelated = makeTodoDTO(
            id: "todo-unrelated",
            title: "Another todo",
            content: "Different description",
            status: .todo,
            dueDate: nil
        )
        let board = makeTodoBoard(
            todo: [existing],
            inProgress: [unrelated],
            done: [existing]
        )

        OfflineSyncURLProtocol.handler = { request in
            recorder.append(request)
            return try Self.response(for: request, encoding: board)
        }

        let matched = try await makeTransport().todoAlreadyExists(
            accountID: 42,
            request: request
        )

        XCTAssertTrue(matched)
        XCTAssertEqual(recorder.requests.count, 1)
        XCTAssertEqual(recorder.requests.first?.httpMethod, "GET")
        XCTAssertEqual(recorder.requests.first?.url?.path, "/api/todos/board")
    }

    func testTodoBoardWithTwoDifferentEquivalentCandidatesThrowsMultipleCandidates() async throws {
        let recorder = OfflineSyncRequestRecorder()
        let request = makeTodoRequest(
            title: "Offline todo",
            content: "Description",
            status: .done,
            dueDate: "2026-08-12"
        )
        let first = makeTodoDTO(
            id: "todo-one",
            title: request.title,
            content: request.content,
            status: .done,
            dueDate: request.dueDate?.rawValue
        )
        let second = makeTodoDTO(
            id: "todo-two",
            title: request.title,
            content: request.content,
            status: .done,
            dueDate: request.dueDate?.rawValue
        )
        let board = makeTodoBoard(todo: [first], done: [second])

        OfflineSyncURLProtocol.handler = { request in
            recorder.append(request)
            return try Self.response(for: request, encoding: board)
        }

        do {
            _ = try await makeTransport().todoAlreadyExists(
                accountID: 42,
                request: request
            )
            XCTFail("Expected multiple equivalent todo candidates to be rejected")
        } catch OfflineCreateDedupeError.multipleCandidates {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertEqual(recorder.requests.count, 1)
    }

    func testCreatePostsDoNotEncodeClientOperationID() async throws {
        let recorder = OfflineSyncRequestRecorder()
        let scheduleResponse = ScheduleSaveResponse(id: UUID())
        let todoResponse = makeTodoDTO(
            id: "created-todo",
            title: "Offline todo",
            content: "Description",
            status: .todo,
            dueDate: nil
        )

        OfflineSyncURLProtocol.handler = { request in
            recorder.append(request)
            switch request.url?.path {
            case "/api/schedules":
                return try Self.response(for: request, encoding: scheduleResponse)
            case "/api/todos":
                return try Self.response(for: request, encoding: todoResponse)
            default:
                throw OfflineSyncURLProtocolError.unexpectedPath
            }
        }

        let transport = makeTransport()
        _ = try await transport.createSchedule(makeScheduleRequest())
        _ = try await transport.createTodo(makeTodoRequest())

        XCTAssertEqual(recorder.requests.map { $0.httpMethod }, ["POST", "POST"])
        let scheduleBody = try XCTUnwrap(Self.jsonBody(recorder.requests[0]))
        let todoBody = try XCTUnwrap(Self.jsonBody(recorder.requests[1]))
        XCTAssertNil(scheduleBody["clientOperationId"])
        XCTAssertNil(todoBody["clientOperationId"])
    }

    private func makeTransport() -> APIOfflineSyncTransport {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [OfflineSyncURLProtocol.self]
        return APIOfflineSyncTransport(
            client: APIClient(
                baseURL: baseURL,
                session: URLSession(configuration: configuration)
            )
        )
    }

    nonisolated private static func response<Value: Encodable>(
        for request: URLRequest,
        encoding value: Value,
        statusCode: Int = 200
    ) throws -> (HTTPURLResponse, Data) {
        guard let url = request.url,
              let response = HTTPURLResponse(
                  url: url,
                  statusCode: statusCode,
                  httpVersion: nil,
                  headerFields: ["Content-Type": "application/json"]
              )
        else { throw OfflineSyncURLProtocolError.invalidURL }
        return (response, try JSONEncoder().encode(value))
    }

    private static func queryItem(named name: String, in request: URLRequest) -> String? {
        URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?
            .queryItems?
            .first(where: { $0.name == name })?
            .value
    }

    private static func jsonBody(_ request: URLRequest) -> [String: Any]? {
        guard let body = requestBody(request) else { return nil }
        return try? JSONSerialization.jsonObject(with: body) as? [String: Any]
    }

    private static func requestBody(_ request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1_024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            guard count > 0 else { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

private final class OfflineSyncRequestRecorder: @unchecked Sendable {
    private let lock = NSLock()
    private var storedRequests: [URLRequest] = []

    func append(_ request: URLRequest) {
        lock.lock()
        storedRequests.append(request)
        lock.unlock()
    }

    var requests: [URLRequest] {
        lock.lock()
        defer { lock.unlock() }
        return storedRequests
    }
}

private enum OfflineSyncURLProtocolError: Error {
    case missingHandler
    case invalidURL
    case unexpectedPath
}

private final class OfflineSyncURLProtocol: URLProtocol, @unchecked Sendable {
    nonisolated(unsafe) static var handler:
        (@Sendable (URLRequest) throws -> (HTTPURLResponse, Data))?

    override class func canInit(with request: URLRequest) -> Bool {
        request.url?.host == "dutypark.test"
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        do {
            guard let handler = Self.handler else {
                throw OfflineSyncURLProtocolError.missingHandler
            }
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}

private func makeScheduleRequest(
    memberID: MemberID = 42,
    content: String = "Offline schedule",
    description: String = "Created without a connection",
    startDateTime: String = "2026-08-23T09:00:00",
    endDateTime: String = "2026-08-23T10:00:00"
) -> ScheduleSaveDTO {
    ScheduleSaveDTO(
        id: nil,
        memberId: memberID,
        content: content,
        description: description,
        visibility: .privateAccess,
        startDateTime: LocalDateTimeValue(rawValue: startDateTime),
        endDateTime: LocalDateTimeValue(rawValue: endDateTime),
        tagFriendIds: nil,
        attachmentSessionId: nil,
        orderedAttachmentIds: [],
        aiTimeParsingRequested: false
    )
}

private func makeScheduleDTO(
    id: ScheduleID,
    content: String = "Offline schedule",
    description: String = "Created without a connection",
    startDateTime: String = "2026-08-23T09:00:00",
    endDateTime: String = "2026-08-23T10:00:00"
) -> ScheduleDTO {
    ScheduleDTO(
        id: id,
        content: content,
        description: description,
        position: 0,
        year: 2026,
        month: 8,
        dayOfMonth: 23,
        startDateTime: LocalDateTimeValue(rawValue: startDateTime),
        endDateTime: LocalDateTimeValue(rawValue: endDateTime),
        isTagged: false,
        owner: "Tester",
        taggedByMember: nil,
        tags: [],
        visibility: .privateAccess,
        dateToCompare: DateOnly(rawValue: "2026-08-23"),
        attachments: [],
        startDate: DateOnly(rawValue: "2026-08-23"),
        daysFromStart: 0,
        endDate: DateOnly(rawValue: "2026-08-23"),
        curDate: DateOnly(rawValue: "2026-08-23"),
        totalDays: 1
    )
}

private func makeTodoRequest(
    title: String = "Offline todo",
    content: String = "Description",
    status: TodoStatus? = .todo,
    dueDate: String? = nil
) -> TodoRequest {
    TodoRequest(
        title: title,
        content: content,
        status: status,
        dueDate: dueDate.map(DateOnly.init(rawValue:)),
        tagFriendIds: nil,
        attachmentSessionId: nil,
        orderedAttachmentIds: []
    )
}

private func makeTodoDTO(
    id: String,
    title: String,
    content: String,
    status: TodoStatus,
    dueDate: String?
) -> TodoDTO {
    TodoDTO(
        id: id,
        title: title,
        content: content,
        position: 0,
        status: status,
        createdDate: LocalDateTimeValue(rawValue: "2026-08-23T00:00:00"),
        completedDate: nil,
        dueDate: dueDate.map(DateOnly.init(rawValue:)),
        isOverdue: false,
        isTagged: false,
        owner: "Tester",
        taggedByMember: nil,
        tags: [],
        hasAttachments: false
    )
}

private func makeTodoBoard(
    todo: [TodoDTO] = [],
    inProgress: [TodoDTO] = [],
    done: [TodoDTO] = []
) -> TodoBoardDTO {
    TodoBoardDTO(
        todo: todo,
        inProgress: inProgress,
        done: done,
        counts: TodoCountsDTO(
            todo: todo.count,
            inProgress: inProgress.count,
            done: done.count,
            total: todo.count + inProgress.count + done.count
        )
    )
}
