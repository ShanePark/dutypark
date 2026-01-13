import Foundation

struct PolicyDto: Decodable, Identifiable {
    let policyType: String
    let version: String
    let content: String
    let effectiveDate: String

    var id: String { "\(policyType)-\(version)" }
}

struct CurrentPoliciesDto: Decodable {
    let terms: PolicyDto?
    let privacy: PolicyDto?
}
