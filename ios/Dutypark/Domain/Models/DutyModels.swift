import Foundation

nonisolated enum DutySource: Codable, Hashable, Sendable {
    case override
    case pattern
    case patternPaused
    case defaultOff
    case unknown(String)

    var rawValue: String {
        switch self {
        case .override: "OVERRIDE"
        case .pattern: "PATTERN"
        case .patternPaused: "PATTERN_PAUSED"
        case .defaultOff: "DEFAULT_OFF"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "OVERRIDE": .override
        case "PATTERN": .pattern
        case "PATTERN_PAUSED": .patternPaused
        case "DEFAULT_OFF": .defaultOff
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct DutyDTO: Codable, Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int
    let dutyType: String?
    let dutyColor: String?
    let isOff: Bool
    let dutyTypeId: DutyTypeID?
    let source: DutySource
}

nonisolated struct DutyTypeDTO: Codable, Equatable, Sendable {
    let id: DutyTypeID?
    let teamId: TeamID
    let name: String
    let position: Int
    let color: String?
    let hidden: Bool
}

nonisolated struct DutyByShiftDTO: Codable, Equatable, Sendable {
    let dutyType: DutyTypeDTO
    let members: [MemberPreviewDTO]
}

nonisolated struct OtherDutyResponse: Codable, Equatable, Sendable {
    let memberId: MemberID
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int64
    let duties: [DutyDTO]
}

nonisolated struct DutyUpdateDTO: Codable, Equatable, Sendable {
    let year: Int
    let month: Int
    let day: Int
    let dutyTypeId: DutyTypeID?
    let memberId: MemberID
}

nonisolated enum Weekday: Codable, Hashable, Sendable {
    case monday, tuesday, wednesday, thursday, friday, saturday, sunday
    case unknown(String)

    var rawValue: String {
        switch self {
        case .monday: "MONDAY"
        case .tuesday: "TUESDAY"
        case .wednesday: "WEDNESDAY"
        case .thursday: "THURSDAY"
        case .friday: "FRIDAY"
        case .saturday: "SATURDAY"
        case .sunday: "SUNDAY"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "MONDAY": .monday
        case "TUESDAY": .tuesday
        case "WEDNESDAY": .wednesday
        case "THURSDAY": .thursday
        case "FRIDAY": .friday
        case "SATURDAY": .saturday
        case "SUNDAY": .sunday
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct DutyPatternDutyTypeDTO: Codable, Equatable, Sendable {
    let id: DutyTypeID
    let name: String
    let color: String
}

nonisolated struct DutyPatternDayDTO: Codable, Equatable, Sendable {
    let weekday: Weekday
    let dutyType: DutyPatternDutyTypeDTO
}

nonisolated struct DutyPatternDetailsDTO: Codable, Equatable, Sendable {
    let days: [DutyPatternDayDTO]
    let holidayOff: Bool
    let effectiveFrom: DateOnly
}

nonisolated struct DutyPatternDTO: Codable, Equatable, Sendable {
    let configurable: Bool
    let reason: String?
    let dutyTypes: [DutyPatternDutyTypeDTO]
    let pattern: DutyPatternDetailsDTO?
}

nonisolated struct DutyPatternDayUpdateDTO: Codable, Equatable, Sendable {
    let weekday: Weekday
    let dutyTypeId: DutyTypeID?
}

nonisolated struct DutyPatternUpdateDTO: Codable, Equatable, Sendable {
    let days: [DutyPatternDayUpdateDTO]
    let holidayOff: Bool
}

nonisolated struct HolidayDTO: Codable, Equatable, Sendable {
    let dateName: String
    let isHoliday: Bool
    let localDate: DateOnly
}
