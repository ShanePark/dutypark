import Foundation

/// The on-disk format is deliberately versioned independently from the API
/// DTOs. A server response changing shape must never make a previously saved
/// cache unsafe to read.
nonisolated enum OfflineStorageConstants {
    static let schemaVersion = 1
    static let rootDirectoryName = "Offline"
}

nonisolated struct OfflineProfileSnapshot: Codable, Equatable, Sendable {
    let memberID: MemberID
    let name: String
    let email: String?
    let teamID: TeamID?
    let teamName: String?
    let calendarVisibility: Visibility
    let hasPassword: Bool
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64

    init(
        memberID: MemberID,
        name: String,
        email: String?,
        teamID: TeamID?,
        teamName: String?,
        calendarVisibility: Visibility = .privateAccess,
        hasPassword: Bool = false,
        hasProfilePhoto: Bool = false,
        profilePhotoVersion: Int64 = 0
    ) {
        self.memberID = memberID
        self.name = name
        self.email = email
        self.teamID = teamID
        self.teamName = teamName
        self.calendarVisibility = calendarVisibility
        self.hasPassword = hasPassword
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
    }

    init(member: MemberDTO) {
        self.init(
            memberID: member.id ?? 0,
            name: member.name,
            email: member.email,
            teamID: member.teamId,
            teamName: member.team,
            calendarVisibility: member.calendarVisibility,
            hasPassword: member.hasPassword,
            hasProfilePhoto: member.hasProfilePhoto,
            profilePhotoVersion: member.profilePhotoVersion
        )
    }

    init(member: LoginMember) {
        self.init(
            memberID: member.id,
            name: member.name,
            email: member.email,
            teamID: member.teamId,
            teamName: member.team
        )
    }
}

nonisolated struct OfflineAccountSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = OfflineStorageConstants.schemaVersion

    let schemaVersion: Int
    let memberID: MemberID
    let profile: OfflineProfileSnapshot
    /// Friend metadata is sufficient for calendar comparison and does not
    /// contain provider login identifiers.
    let friends: [FriendDTO]
    let dDays: [DDayDTO]
    let storedAt: Date

    init(
        memberID: MemberID,
        profile: OfflineProfileSnapshot,
        friends: [FriendDTO] = [],
        dDays: [DDayDTO] = [],
        storedAt: Date = .now,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.memberID = memberID
        self.profile = profile
        self.friends = friends
        self.dDays = dDays
        self.storedAt = storedAt
    }

    init(
        member: MemberDTO,
        friends: [FriendDTO] = [],
        dDays: [DDayDTO] = [],
        storedAt: Date = .now
    ) {
        let profile = OfflineProfileSnapshot(member: member)
        self.init(
            memberID: profile.memberID,
            profile: profile,
            friends: friends,
            dDays: dDays,
            storedAt: storedAt
        )
    }

    init(
        member: LoginMember,
        friends: [FriendDTO] = [],
        dDays: [DDayDTO] = [],
        storedAt: Date = .now
    ) {
        let profile = OfflineProfileSnapshot(member: member)
        self.init(
            memberID: profile.memberID,
            profile: profile,
            friends: friends,
            dDays: dDays,
            storedAt: storedAt
        )
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
            && memberID > 0
            && memberID == profile.memberID
    }
}

/// A calendar month is kept as a value instead of a Date so that cache paths
/// are stable across time zones and daylight-saving changes.
nonisolated struct OfflineMonthKey: Codable, Equatable, Hashable, Comparable, Sendable {
    let year: Int
    let month: Int

    init(year: Int, month: Int) {
        self.year = year
        self.month = month
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month], from: date)
        self.init(year: components.year ?? 1970, month: components.month ?? 1)
    }

    var fileName: String {
        String(format: "%04d-%02d.json", year, month)
    }

    static func < (lhs: Self, rhs: Self) -> Bool {
        lhs.year == rhs.year ? lhs.month < rhs.month : lhs.year < rhs.year
    }

    func offsetByMonths(_ offset: Int) -> Self {
        let zeroBased = year * 12 + (month - 1) + offset
        let normalizedYear = zeroBased >= 0
            ? zeroBased / 12
            : (zeroBased - 11) / 12
        let normalizedMonth = zeroBased - normalizedYear * 12 + 1
        return Self(year: normalizedYear, month: normalizedMonth)
    }
}

nonisolated struct OfflineCacheRangePolicy: Equatable, Sendable {
    let pastMonths: Int
    let futureMonths: Int

    init(pastMonths: Int = 6, futureMonths: Int = 6) {
        self.pastMonths = max(0, pastMonths)
        self.futureMonths = max(0, futureMonths)
    }

    static let rollingThirteenMonths = Self(pastMonths: 6, futureMonths: 6)

    func months(around current: OfflineMonthKey) -> [OfflineMonthKey] {
        (-pastMonths...futureMonths).map { current.offsetByMonths($0) }
    }

    func months(around date: Date, calendar: Calendar = .current) -> [OfflineMonthKey] {
        months(around: OfflineMonthKey(date: date, calendar: calendar))
    }

    func contains(_ key: OfflineMonthKey, around current: OfflineMonthKey) -> Bool {
        let distance = (key.year - current.year) * 12 + key.month - current.month
        return (-pastMonths...futureMonths).contains(distance)
    }
}

/// The API's MemberDTO includes OAuth provider identifiers. They are not
/// needed to render a cached schedule, so month persistence uses this reduced
/// representation and reconstructs MemberDTO values with those fields nil.
nonisolated private struct OfflineCachedMemberSnapshot: Codable, Equatable, Sendable {
    let id: MemberID?
    let name: String
    let email: String?
    let teamId: TeamID?
    let team: String?
    let calendarVisibility: Visibility
    let hasPassword: Bool
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64

    init(member: MemberDTO) {
        id = member.id
        name = member.name
        email = member.email
        teamId = member.teamId
        team = member.team
        calendarVisibility = member.calendarVisibility
        hasPassword = member.hasPassword
        hasProfilePhoto = member.hasProfilePhoto
        profilePhotoVersion = member.profilePhotoVersion
    }

    func member() -> MemberDTO {
        MemberDTO(
            id: id,
            name: name,
            email: email,
            teamId: teamId,
            team: team,
            calendarVisibility: calendarVisibility,
            kakaoId: nil,
            naverId: nil,
            appleId: nil,
            hasPassword: hasPassword,
            hasProfilePhoto: hasProfilePhoto,
            profilePhotoVersion: profilePhotoVersion
        )
    }
}

nonisolated private struct OfflineCachedScheduleSnapshot: Codable, Equatable, Sendable {
    let id: ScheduleID
    let content: String
    let description: String
    let position: Int
    let year: Int
    let month: Int
    let dayOfMonth: Int
    let startDateTime: LocalDateTimeValue
    let endDateTime: LocalDateTimeValue
    let isTagged: Bool
    let owner: String
    let taggedByMember: MemberPreviewDTO?
    let tags: [OfflineCachedMemberSnapshot]
    let visibility: Visibility?
    let dateToCompare: DateOnly
    let attachments: [AttachmentDTO]
    let startDate: DateOnly
    let daysFromStart: Int
    let endDate: DateOnly
    let curDate: DateOnly
    let totalDays: Int

    init(schedule: ScheduleDTO) {
        id = schedule.id
        content = schedule.content
        description = schedule.description
        position = schedule.position
        year = schedule.year
        month = schedule.month
        dayOfMonth = schedule.dayOfMonth
        startDateTime = schedule.startDateTime
        endDateTime = schedule.endDateTime
        isTagged = schedule.isTagged
        owner = schedule.owner
        taggedByMember = schedule.taggedByMember
        tags = schedule.tags.map(OfflineCachedMemberSnapshot.init(member:))
        visibility = schedule.visibility
        dateToCompare = schedule.dateToCompare
        attachments = schedule.attachments
        startDate = schedule.startDate
        daysFromStart = schedule.daysFromStart
        endDate = schedule.endDate
        curDate = schedule.curDate
        totalDays = schedule.totalDays
    }

    func schedule() -> ScheduleDTO {
        ScheduleDTO(
            id: id,
            content: content,
            description: description,
            position: position,
            year: year,
            month: month,
            dayOfMonth: dayOfMonth,
            startDateTime: startDateTime,
            endDateTime: endDateTime,
            isTagged: isTagged,
            owner: owner,
            taggedByMember: taggedByMember,
            tags: tags.map { $0.member() },
            visibility: visibility,
            dateToCompare: dateToCompare,
            attachments: attachments,
            startDate: startDate,
            daysFromStart: daysFromStart,
            endDate: endDate,
            curDate: curDate,
            totalDays: totalDays
        )
    }
}

nonisolated struct OfflineMonthSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = OfflineStorageConstants.schemaVersion

    let schemaVersion: Int
    let accountID: MemberID
    let key: OfflineMonthKey
    /// The server returns one calendar/schedule/holiday array for each of the
    /// 42 cells in a month view. Keeping the shape unchanged makes the cached
    /// value directly consumable by CalendarViewModel.
    let calendar: [TeamDayDTO]
    let schedules: [[ScheduleDTO]]
    let duties: [DutyDTO]
    let holidays: [[HolidayDTO]]
    let otherDuties: [OtherDutyResponse]
    let storedAt: Date

    init(
        accountID: MemberID,
        key: OfflineMonthKey,
        calendar: [TeamDayDTO],
        schedules: [[ScheduleDTO]],
        duties: [DutyDTO],
        holidays: [[HolidayDTO]],
        otherDuties: [OtherDutyResponse],
        storedAt: Date = .now,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.key = key
        self.calendar = calendar
        self.schedules = schedules
        self.duties = duties
        self.holidays = holidays
        self.otherDuties = otherDuties
        self.storedAt = storedAt
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion
            && accountID > 0
            && key.month >= 1
            && key.month <= 12
            && calendar.count == 42
            && schedules.count == 42
            && holidays.count == 42
    }

    private enum CodingKeys: String, CodingKey {
        case schemaVersion
        case accountID
        case key
        case calendar
        case schedules
        case duties
        case holidays
        case otherDuties
        case storedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        schemaVersion = try container.decode(Int.self, forKey: .schemaVersion)
        accountID = try container.decode(MemberID.self, forKey: .accountID)
        key = try container.decode(OfflineMonthKey.self, forKey: .key)
        calendar = try container.decode([TeamDayDTO].self, forKey: .calendar)
        let cachedSchedules = try container.decode(
            [[OfflineCachedScheduleSnapshot]].self,
            forKey: .schedules
        )
        schedules = cachedSchedules.map { $0.map { $0.schedule() } }
        duties = try container.decode([DutyDTO].self, forKey: .duties)
        holidays = try container.decode([[HolidayDTO]].self, forKey: .holidays)
        otherDuties = try container.decode([OtherDutyResponse].self, forKey: .otherDuties)
        storedAt = try container.decode(Date.self, forKey: .storedAt)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(schemaVersion, forKey: .schemaVersion)
        try container.encode(accountID, forKey: .accountID)
        try container.encode(key, forKey: .key)
        try container.encode(calendar, forKey: .calendar)
        try container.encode(
            schedules.map { $0.map(OfflineCachedScheduleSnapshot.init(schedule:)) },
            forKey: .schedules
        )
        try container.encode(duties, forKey: .duties)
        try container.encode(holidays, forKey: .holidays)
        try container.encode(otherDuties, forKey: .otherDuties)
        try container.encode(storedAt, forKey: .storedAt)
    }
}

nonisolated struct OfflineTodoBoardSnapshot: Codable, Equatable, Sendable {
    static let currentSchemaVersion = OfflineStorageConstants.schemaVersion

    let schemaVersion: Int
    let accountID: MemberID
    let board: TodoBoardDTO
    let storedAt: Date

    init(
        accountID: MemberID,
        board: TodoBoardDTO,
        storedAt: Date = .now,
        schemaVersion: Int = currentSchemaVersion
    ) {
        self.schemaVersion = schemaVersion
        self.accountID = accountID
        self.board = board
        self.storedAt = storedAt
    }

    var isCurrentSchema: Bool {
        schemaVersion == Self.currentSchemaVersion && accountID > 0
    }
}
