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

    // MARK: - Auth Extensions
    static func logout() -> Endpoint {
        Endpoint(path: "/auth/logout", method: .post)
    }

    static var refreshTokens: Endpoint {
        Endpoint(path: "/auth/refresh-tokens")
    }

    static func deleteRefreshToken(id: Int) -> Endpoint {
        Endpoint(path: "/auth/refresh-tokens/\(id)", method: .delete)
    }

    static var deleteOtherRefreshTokens: Endpoint {
        Endpoint(path: "/auth/refresh-tokens/others", method: .delete)
    }

    static func changePassword(currentPassword: String, newPassword: String) -> Endpoint {
        Endpoint(path: "/auth/password", method: .put, body: ChangePasswordRequest(currentPassword: currentPassword, newPassword: newPassword))
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

    // MARK: - Duty Extensions
    static func otherDuties(memberIds: [Int], year: Int, month: Int) -> Endpoint {
        let idsParam = memberIds.map { "memberIds=\($0)" }.joined(separator: "&")
        return Endpoint(path: "/duty/others?\(idsParam)&year=\(year)&month=\(month)")
    }

    static func changeDuty(request: DutyChangeRequest) -> Endpoint {
        Endpoint(path: "/duty/change", method: .put, body: request)
    }

    static func batchDuty(request: DutyBatchRequest) -> Endpoint {
        Endpoint(path: "/duty/batch", method: .put, body: request)
    }

    static func holidays(year: Int, month: Int) -> Endpoint {
        Endpoint(path: "/holidays?year=\(year)&month=\(month)")
    }

    static func canManageMember(memberId: Int) -> Endpoint {
        Endpoint(path: "/members/\(memberId)/canManage")
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

    // MARK: - Schedule Extensions
    static func searchSchedules(memberId: Int, query: String, page: Int = 0, size: Int = 10) -> Endpoint {
        let encodedQuery = query.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? query
        return Endpoint(path: "/schedules/\(memberId)/search?q=\(encodedQuery)&page=\(page)&size=\(size)")
    }

    static func updateSchedulePositions(orderedIds: [String]) -> Endpoint {
        Endpoint(path: "/schedules/positions", method: .patch, body: OrderedIdsRequest(orderedIds: orderedIds))
    }

    static func tagFriend(scheduleId: String, friendId: Int) -> Endpoint {
        Endpoint(path: "/schedules/\(scheduleId)/tags/\(friendId)", method: .post)
    }

    static func untagFriend(scheduleId: String, friendId: Int) -> Endpoint {
        Endpoint(path: "/schedules/\(scheduleId)/tags/\(friendId)", method: .delete)
    }

    static func untagSelf(scheduleId: String) -> Endpoint {
        Endpoint(path: "/schedules/\(scheduleId)/tags", method: .delete)
    }

    // MARK: - Todo
    static var todos: Endpoint {
        Endpoint(path: "/todos")
    }

    static func createTodo(request: TodoCreateRequest) -> Endpoint {
        Endpoint(path: "/todos", method: .post, body: request)
    }

    static func updateTodo(id: String, request: TodoUpdateRequest) -> Endpoint {
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

    // MARK: - Todo Extensions
    static var todoBoard: Endpoint {
        Endpoint(path: "/todos/board")
    }

    static func todosByStatus(status: String) -> Endpoint {
        Endpoint(path: "/todos/status/\(status)")
    }

    static func todosByMonth(year: Int, month: Int) -> Endpoint {
        Endpoint(path: "/todos/calendar?year=\(year)&month=\(month)")
    }

    static func todosDue(date: String) -> Endpoint {
        Endpoint(path: "/todos/due?date=\(date)")
    }

    static var overdueTodos: Endpoint {
        Endpoint(path: "/todos/overdue")
    }

    static func changeTodoStatus(id: String, request: TodoStatusChangeRequest) -> Endpoint {
        Endpoint(path: "/todos/\(id)/status", method: .patch, body: request)
    }

    static func updateTodoPositions(request: TodoPositionUpdateRequest) -> Endpoint {
        Endpoint(path: "/todos/positions", method: .patch, body: request)
    }

    // MARK: - Member
    static var myProfile: Endpoint {
        Endpoint(path: "/members/me")
    }

    // MARK: - Member Extensions
    static func member(id: Int) -> Endpoint {
        Endpoint(path: "/members/\(id)")
    }

    static func updateVisibility(memberId: Int, visibility: String) -> Endpoint {
        Endpoint(path: "/members/\(memberId)/visibility", method: .put, body: VisibilityRequest(visibility: visibility))
    }

    static var familyMembers: Endpoint {
        Endpoint(path: "/members/family")
    }

    static var managers: Endpoint {
        Endpoint(path: "/members/managers")
    }

    static var managedMembers: Endpoint {
        Endpoint(path: "/members/managed")
    }

    static func assignManager(managerId: Int) -> Endpoint {
        Endpoint(path: "/members/manager/\(managerId)", method: .post)
    }

    static func removeManager(managerId: Int) -> Endpoint {
        Endpoint(path: "/members/manager/\(managerId)", method: .delete)
    }

    // MARK: - Friends
    static var friends: Endpoint {
        Endpoint(path: "/friends")
    }

    // MARK: - Friends Extensions
    static func searchFriends(keyword: String, page: Int = 0, size: Int = 10) -> Endpoint {
        let encodedKeyword = keyword.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? keyword
        return Endpoint(path: "/friends/search?keyword=\(encodedKeyword)&page=\(page)&size=\(size)")
    }

    static func sendFriendRequest(toMemberId: Int) -> Endpoint {
        Endpoint(path: "/friends/request/send/\(toMemberId)", method: .post)
    }

    static func cancelFriendRequest(toMemberId: Int) -> Endpoint {
        Endpoint(path: "/friends/request/cancel/\(toMemberId)", method: .delete)
    }

    static func acceptFriendRequest(fromMemberId: Int) -> Endpoint {
        Endpoint(path: "/friends/request/accept/\(fromMemberId)", method: .post)
    }

    static func rejectFriendRequest(fromMemberId: Int) -> Endpoint {
        Endpoint(path: "/friends/request/reject/\(fromMemberId)", method: .post)
    }

    static func upgradeToFamily(friendId: Int) -> Endpoint {
        Endpoint(path: "/friends/family/\(friendId)", method: .put)
    }

    static func demoteFromFamily(friendId: Int) -> Endpoint {
        Endpoint(path: "/friends/family/\(friendId)", method: .delete)
    }

    static func unfriend(memberId: Int) -> Endpoint {
        Endpoint(path: "/friends/\(memberId)", method: .delete)
    }

    static func pinFriend(friendId: Int) -> Endpoint {
        Endpoint(path: "/friends/pin/\(friendId)", method: .patch)
    }

    static func unpinFriend(friendId: Int) -> Endpoint {
        Endpoint(path: "/friends/unpin/\(friendId)", method: .patch)
    }

    static func updatePinOrder(orderedIds: [Int]) -> Endpoint {
        Endpoint(path: "/friends/pin/order", method: .patch, body: PinOrderRequest(orderedIds: orderedIds))
    }

    // MARK: - D-Day
    static var ddays: Endpoint {
        Endpoint(path: "/dday")
    }

    // MARK: - D-Day Extensions
    static func memberDdays(memberId: Int) -> Endpoint {
        Endpoint(path: "/dday/\(memberId)")
    }

    static func createDday(request: DDaySaveDto) -> Endpoint {
        Endpoint(path: "/dday", method: .post, body: request)
    }

    static func deleteDday(id: Int) -> Endpoint {
        Endpoint(path: "/dday/\(id)", method: .delete)
    }

    // MARK: - Notifications
    static func notifications(page: Int = 0, size: Int = 20) -> Endpoint {
        Endpoint(path: "/notifications?page=\(page)&size=\(size)")
    }

    static var unreadNotifications: Endpoint {
        Endpoint(path: "/notifications/unread")
    }

    static var notificationCount: Endpoint {
        Endpoint(path: "/notifications/count")
    }

    static var friendRequestCount: Endpoint {
        Endpoint(path: "/notifications/friend-request-count")
    }

    static func markNotificationRead(id: String) -> Endpoint {
        Endpoint(path: "/notifications/\(id)/read", method: .patch)
    }

    static var markAllNotificationsRead: Endpoint {
        Endpoint(path: "/notifications/read-all", method: .patch)
    }

    static func deleteNotification(id: String) -> Endpoint {
        Endpoint(path: "/notifications/\(id)", method: .delete)
    }

    static var deleteReadNotifications: Endpoint {
        Endpoint(path: "/notifications/read", method: .delete)
    }

    // MARK: - Team
    static func team(id: Int) -> Endpoint {
        Endpoint(path: "/teams/\(id)")
    }

    static func myTeam(year: Int, month: Int) -> Endpoint {
        Endpoint(path: "/teams/my?year=\(year)&month=\(month)")
    }

    static func teamShift(year: Int, month: Int, day: Int) -> Endpoint {
        Endpoint(path: "/teams/shift?year=\(year)&month=\(month)&day=\(day)")
    }

    static func teamSchedules(year: Int, month: Int) -> Endpoint {
        Endpoint(path: "/teams/schedules?year=\(year)&month=\(month)")
    }

    static func createTeamSchedule(request: TeamScheduleSaveDto) -> Endpoint {
        Endpoint(path: "/teams/schedules", method: .post, body: request)
    }

    static func deleteTeamSchedule(id: String) -> Endpoint {
        Endpoint(path: "/teams/schedules/\(id)", method: .delete)
    }

    // MARK: - Attachments
    static func createAttachmentSession(request: CreateSessionRequest) -> Endpoint {
        Endpoint(path: "/attachments/sessions", method: .post, body: request)
    }

    static func deleteAttachmentSession(sessionId: String) -> Endpoint {
        Endpoint(path: "/attachments/sessions/\(sessionId)", method: .delete)
    }

    static func attachments(contextType: String, contextId: String) -> Endpoint {
        Endpoint(path: "/attachments?contextType=\(contextType)&contextId=\(contextId)")
    }

    static func deleteAttachment(id: String) -> Endpoint {
        Endpoint(path: "/attachments/\(id)", method: .delete)
    }
}
