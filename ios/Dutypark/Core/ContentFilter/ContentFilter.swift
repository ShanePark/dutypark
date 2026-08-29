import Foundation

/// Client-side check that keeps prohibited content from being posted, as App Store Guideline 1.2 requires.
///
/// The banned word list is served already normalized by `GET /api/public-content/banned-words`, so input
/// must be normalized the same way before matching: NFKC, lowercased, and stripped of everything that is
/// not a letter or a decimal digit. Dropping separators is what makes `f.u.c.k` and `시 발` match too.
///
/// Matching is a plain substring test. See `src/main/resources/public-content/README.md` for the list rules
/// that keep that from flagging everyday text, and `docs/design/content-filter.md` for the full contract.
nonisolated enum ContentFilter {
    static func normalizeForMatching(_ value: String) -> String {
        let kept = value.precomposedStringWithCompatibilityMapping
            .lowercased()
            .unicodeScalars
            .filter { keptCategories.contains($0.properties.generalCategory) }
        return String(String.UnicodeScalarView(kept))
    }

    /// Kept scalars are spelled out by Unicode general category rather than taken from `Character.isLetter`
    /// and `isNumber`, which are wider than the web's `\p{L}`/`\p{Nd}` and the server's `isLetterOrDigit`.
    /// `〇` is a letter *number* that Swift alone would keep, and any kept character splits a banned word apart.
    private static let keptCategories: Set<Unicode.GeneralCategory> = [
        .uppercaseLetter, .lowercaseLetter, .titlecaseLetter, .modifierLetter, .otherLetter, .decimalNumber,
    ]

    /// Applies the same matching normalization to list entries and rejects values that cannot
    /// contribute to a match. First occurrence order is retained after normalization.
    static func normalizedWords(_ candidates: [String]) -> [String] {
        var seen = Set<String>()
        return candidates.compactMap { candidate in
            let normalized = normalizeForMatching(candidate)
            guard !normalized.isEmpty, seen.insert(normalized).inserted else { return nil }
            return normalized
        }
    }

    static func bannedWord(in values: [String?], words: [String]) -> String? {
        guard !words.isEmpty else { return nil }

        for value in values {
            guard let value, !value.isEmpty else { continue }
            let normalized = normalizeForMatching(value)
            guard !normalized.isEmpty else { continue }

            if let match = words.first(where: { normalized.contains($0) }) {
                return match
            }
        }

        return nil
    }
}
