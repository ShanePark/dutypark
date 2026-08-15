#if DEBUG
import Foundation

nonisolated struct AdminVisualFixtureRepository: AdminRepositoryProtocol, Sendable {
    private let member = AdminMemberDTO(
        id: 7,
        name: "관리자 검증 회원",
        email: "visual-admin@duty.park",
        teamId: 101,
        teamName: "시각 검증팀",
        tokens: [Self.session],
        hasProfilePhoto: false,
        profilePhotoVersion: 0
    )

    private let memberWithoutSessions = AdminMemberDTO(
        id: 8,
        name: "세션 없는 회원",
        email: "no-session@duty.park",
        teamId: 101,
        teamName: "시각 검증팀",
        tokens: [],
        hasProfilePhoto: false,
        profilePhotoVersion: 0
    )

    private static let session = SettingsRefreshToken(
        memberName: "관리자 검증 회원",
        memberId: 7,
        validUntil: "2026-09-01T00:00:00",
        createdDate: "2026-08-01T00:00:00",
        lastUsed: "2026-08-15T09:00:00",
        remoteAddr: "127.0.0.1",
        id: 99,
        userAgent: .init(os: "iOS", browser: "Dutypark", device: "iPhone 13 mini"),
        isCurrentLogin: false
    )

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        pageResponse(content: [member, memberWithoutSessions], page: page, size: size)
    }

    func memberDetail(id: MemberID) async throws -> AdminMemberDetailDTO {
        AdminMemberDetailDTO(
            id: member.id,
            name: member.name,
            email: member.email,
            teamId: member.teamId,
            teamName: member.teamName,
            calendarVisibility: .friends,
            hasProfilePhoto: false,
            profilePhotoVersion: 0,
            serviceAdmin: false,
            teamAdmin: false,
            teamManager: false,
            auxiliaryAccount: false,
            hasPassword: true,
            authProviders: ["LOCAL"],
            createdDate: LocalDateTimeValue(rawValue: "2026-01-01T09:00:00"),
            lastModifiedDate: LocalDateTimeValue(rawValue: "2026-08-15T09:00:00"),
            activeSessionCount: 1,
            pushEnabledSessionCount: 1,
            lastActiveAt: LocalDateTimeValue(rawValue: "2026-08-15T09:00:00"),
            totalScheduleCount: 12,
            upcomingScheduleCount: 3,
            taggedScheduleCount: 2,
            totalTodoCount: 8,
            todoCount: 2,
            inProgressTodoCount: 1,
            doneTodoCount: 5,
            overdueTodoCount: 1,
            dueTodayTodoCount: 1,
            dDays: [
                DDayDTO(
                    id: 1,
                    title: "공개 일정",
                    date: DateOnly(rawValue: "2026-08-20"),
                    isPrivate: false,
                    calc: 0,
                    daysLeft: 5
                ),
                DDayDTO(
                    id: 2,
                    title: "비공개 일정",
                    date: DateOnly(rawValue: "2026-09-01"),
                    isPrivate: true,
                    calc: 0,
                    daysLeft: 17
                ),
                DDayDTO(
                    id: 3,
                    title: "또 다른 공개 일정",
                    date: DateOnly(rawValue: "2026-10-01"),
                    isPrivate: false,
                    calc: 0,
                    daysLeft: 47
                ),
            ],
            friendCount: 4,
            familyCount: 2,
            pendingReceivedFriendRequestCount: 2,
            pendingSentFriendRequestCount: 1,
            managerCount: 1,
            managedMemberCount: 0,
            managerNames: ["Dutypark 관리자"],
            managedMemberNames: [],
            totalNotificationCount: 6,
            unreadNotificationCount: 1
        )
    }

    func sessions() async throws -> [SettingsRefreshToken] {
        [Self.session]
    }

    func revokeSession(id: Int64) async throws {}

    func changePassword(memberID: MemberID, newPassword: String) async throws {}

    func teams(keyword: String, page: Int, size: Int) async throws -> PageResponse<SimpleTeamDTO> {
        pageResponse(
            content: [
                SimpleTeamDTO(
                    id: 101,
                    name: "시각 검증팀",
                    description: "관리자 확인 패널 캡처용 팀",
                    memberCount: 0
                )
            ],
            page: page,
            size: size
        )
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult { .ok }

    func createTeam(name: String, description: String) async throws -> TeamDTO {
        throw APIError.invalidResponse
    }

    func deleteTeam(id: TeamID) async throws {}

    private func pageResponse<Element: Codable & Equatable & Sendable>(
        content: [Element],
        page: Int,
        size: Int
    ) -> PageResponse<Element> {
        PageResponse(
            content: content,
            totalPages: 1,
            totalElements: Int64(content.count),
            last: true,
            first: true,
            size: size,
            number: page,
            numberOfElements: content.count,
            empty: content.isEmpty
        )
    }
}
#endif
