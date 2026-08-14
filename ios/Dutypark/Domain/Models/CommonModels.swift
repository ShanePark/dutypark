import Foundation

typealias MemberID = Int64
typealias TeamID = Int64
typealias DutyTypeID = Int64
typealias ScheduleID = UUID
typealias TodoID = UUID
typealias AttachmentID = UUID
typealias NotificationID = UUID

nonisolated enum JSONValue: Codable, Equatable, Sendable {
    case string(String)
    case integer(Int64)
    case number(Double)
    case boolean(Bool)
    case object([String: JSONValue])
    case array([JSONValue])
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(Bool.self) {
            self = .boolean(value)
        } else if let value = try? container.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode([String: JSONValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([JSONValue].self) {
            self = .array(value)
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "Unsupported JSON value")
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let value): try container.encode(value)
        case .integer(let value): try container.encode(value)
        case .number(let value): try container.encode(value)
        case .boolean(let value): try container.encode(value)
        case .object(let value): try container.encode(value)
        case .array(let value): try container.encode(value)
        case .null: try container.encodeNil()
        }
    }
}

nonisolated struct APIFieldError: Codable, Equatable, Sendable {
    let field: String
    let code: String
}

nonisolated struct APIErrorResponse: Codable, Equatable, Sendable {
    let status: Int
    let code: String
    let details: [String: JSONValue]?
    let fieldErrors: [APIFieldError]

    private enum CodingKeys: String, CodingKey {
        case status, code, details, fieldErrors
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        status = try container.decode(Int.self, forKey: .status)
        code = try container.decode(String.self, forKey: .code)
        details = try container.decodeIfPresent([String: JSONValue].self, forKey: .details)
        fieldErrors = try container.decodeIfPresent([APIFieldError].self, forKey: .fieldErrors) ?? []
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(status, forKey: .status)
        try container.encode(code, forKey: .code)
        try container.encodeIfPresent(details, forKey: .details)
        if !fieldErrors.isEmpty {
            try container.encode(fieldErrors, forKey: .fieldErrors)
        }
    }
}

nonisolated struct PageResponse<Element: Codable & Equatable & Sendable>: Codable, Equatable, Sendable {
    let content: [Element]
    let totalPages: Int
    let totalElements: Int64
    let last: Bool
    let first: Bool
    let size: Int
    let number: Int
    let numberOfElements: Int
    let empty: Bool

    private enum CodingKeys: String, CodingKey {
        case content, totalPages, totalElements, last, first, size, number, numberOfElements, empty
    }
}

nonisolated struct DateOnly: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct LocalDateTimeValue: RawRepresentable, Codable, Hashable, Sendable {
    let rawValue: String

    init(rawValue: String) {
        self.rawValue = rawValue
    }

    init(from decoder: Decoder) throws {
        rawValue = try decoder.singleValueContainer().decode(String.self)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct CountResponse: Codable, Equatable, Sendable {
    let count: Int
}
