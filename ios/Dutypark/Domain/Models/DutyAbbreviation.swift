import Foundation

/// Only explicit overrides are stored; automatic labels follow the current full name.
nonisolated enum DutyAbbreviation {
    static let maximumLength = 3

    /// Prepares a request value while preserving an explicit empty string reset.
    /// The server turns that blank value into a null stored override.
    static func normalizeForSubmission(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "" : trimmed
    }

    static func normalize(_ value: String?) -> String? {
        guard let normalized = normalizeForSubmission(value), !normalized.isEmpty else {
            return nil
        }
        return normalized
    }

    static func resolve(_ name: String, override: String? = nil) -> String {
        let normalizedOverride = normalize(override)
        let automatic = name.trimmingCharacters(in: .whitespacesAndNewlines).first.map(String.init) ?? ""
        guard let normalizedOverride, isValidNormalized(normalizedOverride) else {
            return automatic
        }
        return normalizedOverride
    }

    static func isValid(_ value: String?) -> Bool {
        guard let normalized = normalize(value) else { return true }
        return isValidNormalized(normalized)
    }

    private static func isValidNormalized(_ value: String) -> Bool {
        guard (1...maximumLength).contains(value.count) else { return false }
        return value.allSatisfy { character in
            guard character.unicodeScalars.count == 1,
                  let scalar = character.unicodeScalars.first
            else { return false }

            return (65...90).contains(scalar.value)
                || (97...122).contains(scalar.value)
                || (0xAC00...0xD7A3).contains(scalar.value)
        }
    }
}
