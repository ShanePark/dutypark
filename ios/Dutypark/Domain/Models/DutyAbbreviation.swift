import Foundation

/// Only explicit overrides are stored; automatic labels follow the current full name.
nonisolated enum DutyAbbreviation {
    static let maximumLength = 10

    static func normalize(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else {
            return nil
        }
        return value
    }

    static func resolve(_ name: String, override: String? = nil) -> String {
        normalize(override) ?? name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? ""
    }

    static func isValid(_ value: String?) -> Bool {
        // Match the server's @Size and web input limits, including surrogate pairs.
        (normalize(value)?.utf16.count ?? 0) <= maximumLength
    }
}
