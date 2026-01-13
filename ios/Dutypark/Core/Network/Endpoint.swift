import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case patch = "PATCH"
    case delete = "DELETE"
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    let body: Encodable?

    init(path: String, method: HTTPMethod = .get, body: Encodable? = nil) {
        self.path = path
        self.method = method
        self.body = body
    }
}

extension Endpoint {
    // MARK: - Auth
    static func login(email: String, password: String) -> Endpoint {
        Endpoint(
            path: "/auth/token/bearer",
            method: .post,
            body: LoginRequest(email: email, password: password)
        )
    }

    static func refreshToken(token: String) -> Endpoint {
        Endpoint(
            path: "/auth/refresh/bearer",
            method: .post,
            body: RefreshTokenRequest(refreshToken: token)
        )
    }

    static var authStatus: Endpoint {
        Endpoint(path: "/auth/status")
    }

    // MARK: - Dashboard
    static var dashboard: Endpoint {
        Endpoint(path: "/dashboard/my")
    }

    static var friendsDashboard: Endpoint {
        Endpoint(path: "/dashboard/friends")
    }

    // MARK: - Duty
    static func duties(memberId: Int, year: Int, month: Int) -> Endpoint {
        Endpoint(path: "/duty/\(memberId)?year=\(year)&month=\(month)")
    }

    // MARK: - Schedule
    static func schedules(year: Int, month: Int) -> Endpoint {
        Endpoint(path: "/schedules?year=\(year)&month=\(month)")
    }

    static func schedule(id: String) -> Endpoint {
        Endpoint(path: "/schedules/\(id)")
    }

    static func createSchedule(request: CreateScheduleRequest) -> Endpoint {
        Endpoint(path: "/schedules", method: .post, body: request)
    }

    static func updateSchedule(id: String, request: UpdateScheduleRequest) -> Endpoint {
        Endpoint(path: "/schedules/\(id)", method: .put, body: request)
    }

    static func deleteSchedule(id: String) -> Endpoint {
        Endpoint(path: "/schedules/\(id)", method: .delete)
    }

    // MARK: - Todo
    static var todos: Endpoint {
        Endpoint(path: "/todos")
    }

    static func createTodo(request: CreateTodoRequest) -> Endpoint {
        Endpoint(path: "/todos", method: .post, body: request)
    }

    static func updateTodo(id: String, request: UpdateTodoRequest) -> Endpoint {
        Endpoint(path: "/todos/\(id)", method: .put, body: request)
    }

    static func deleteTodo(id: String) -> Endpoint {
        Endpoint(path: "/todos/\(id)", method: .delete)
    }

    static func completeTodo(id: String) -> Endpoint {
        Endpoint(path: "/todos/\(id)/complete", method: .post)
    }

    static func reopenTodo(id: String) -> Endpoint {
        Endpoint(path: "/todos/\(id)/reopen", method: .post)
    }

    // MARK: - Member
    static var myProfile: Endpoint {
        Endpoint(path: "/members/me")
    }

    // MARK: - Friends
    static var friends: Endpoint {
        Endpoint(path: "/friends")
    }

    // MARK: - D-Day
    static var ddays: Endpoint {
        Endpoint(path: "/dday")
    }
}
