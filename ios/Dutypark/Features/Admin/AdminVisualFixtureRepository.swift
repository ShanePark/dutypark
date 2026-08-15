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

    private static let teamFixtures: [SimpleTeamDTO] = [
        SimpleTeamDTO(
            id: 101,
            name: "시각 검증팀",
            description: "관리자 팀 목록 시각 검증",
            memberCount: 0
        ),
    ] + (1...11).map { index in
        SimpleTeamDTO(
            id: TeamID(101 + index),
            name: "운영팀 \(index)",
            description: "모바일 목록 계층 검증 \(index)",
            memberCount: Int64(index)
        )
    }

    func members(keyword: String, page: Int, size: Int) async throws -> PageResponse<AdminMemberDTO> {
        let normalizedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let allMembers = [member, memberWithoutSessions]
        let filteredMembers = normalizedKeyword.isEmpty
            ? allMembers
            : allMembers.filter {
                $0.name.localizedCaseInsensitiveContains(normalizedKeyword)
                    || $0.email?.localizedCaseInsensitiveContains(normalizedKeyword) == true
            }
        return pageResponse(content: filteredMembers, page: page, size: size)
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
            serviceAdmin: true,
            teamAdmin: false,
            teamManager: true,
            auxiliaryAccount: true,
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
            managedMemberCount: 2,
            managerNames: ["Dutypark 관리자"],
            managedMemberNames: ["관리 회원 A", "관리 회원 B"],
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
        let filtered = Self.teamFixtures.filter { team in
            keyword.isEmpty
                || team.name.localizedCaseInsensitiveContains(keyword)
                || team.description?.localizedCaseInsensitiveContains(keyword) == true
        }
        let start = page * size
        let content: [SimpleTeamDTO]
        if filtered.indices.contains(start) {
            content = Array(filtered[start..<min(start + size, filtered.count)])
        } else {
            content = []
        }
        let totalPages = filtered.isEmpty ? 0 : (filtered.count + size - 1) / size
        return PageResponse(
            content: content,
            totalPages: totalPages,
            totalElements: Int64(filtered.count),
            last: page >= totalPages - 1,
            first: page == 0,
            size: size,
            number: page,
            numberOfElements: content.count,
            empty: content.isEmpty
        )
    }

    func checkTeamName(_ name: String) async throws -> AdminTeamNameCheckResult { .ok }

    func createTeam(name: String, description: String) async throws -> TeamDTO {
        TeamDTO(
            id: 9001,
            name: name,
            description: description,
            dutyTypes: [],
            members: [],
            createdDate: LocalDateTimeValue(rawValue: "2026-08-15T21:00:00"),
            lastModifiedDate: LocalDateTimeValue(rawValue: "2026-08-15T21:00:00"),
            adminId: nil,
            adminName: nil,
            dutyBatchTemplate: nil
        )
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
