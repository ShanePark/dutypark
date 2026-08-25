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

    func testCreatePostsWithoutAnIdempotencyHeader() async throws {
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
        XCTAssertNil(recorder.requests[0].value(forHTTPHeaderField: "Idempotency-Key"))
        XCTAssertNil(recorder.requests[1].value(forHTTPHeaderField: "Idempotency-Key"))
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
