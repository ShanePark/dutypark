import Foundation

nonisolated enum PolicyType: Codable, Hashable, Sendable {
    case terms
    case privacy
    case unknown(String)

    var rawValue: String {
        switch self {
        case .terms: "TERMS"
        case .privacy: "PRIVACY"
        case .unknown(let value): value
        }
    }

    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = switch value {
        case "TERMS": .terms
        case "PRIVACY": .privacy
        default: .unknown(value)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

nonisolated struct PolicyDTO: Codable, Equatable, Sendable {
    let policyType: PolicyType
    let version: String
    let content: String
    let effectiveDate: DateOnly
}

nonisolated struct CurrentPoliciesDTO: Codable, Equatable, Sendable {
    let terms: PolicyDTO?
    let privacy: PolicyDTO?
}
