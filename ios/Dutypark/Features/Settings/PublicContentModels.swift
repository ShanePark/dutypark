import Foundation

nonisolated protocol PublicContentEnvelope: Decodable, Sendable {
    var schemaVersion: Int { get }
}

nonisolated struct PublicGuideContent: PublicContentEnvelope, Equatable {
    let schemaVersion: Int
    let contentVersion: String
    let locale: String
    let title: String
    let description: String
    let footer: String
    let actions: PublicGuideActions
    let sections: [PublicGuideSection]
}

nonisolated struct PublicGuideActions: Decodable, Equatable, Sendable {
    let expandAll: String
    let collapseAll: String
}

nonisolated struct PublicGuideSection: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let summary: String
    let cards: [PublicGuideCard]
}

nonisolated struct PublicGuideCard: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let items: [String]
}

nonisolated struct PublicReleaseNotesPage: PublicContentEnvelope, Equatable {
    let schemaVersion: Int
    let contentVersion: String
    let locale: String
    let labels: PublicReleaseNoteLabels
    let items: [PublicReleaseNote]
    let page: Int
    let size: Int
    let totalElements: Int
    let totalPages: Int
    let hasNext: Bool
}

nonisolated struct PublicReleaseNoteLabels: Decodable, Equatable, Sendable {
    let title: String
    let count: String
    let loadMore: String
    let latest: String
    let pr: String
    let areas: String
    let categoryLabels: [String: String]
    let areaLabels: [String: String]

    func countText(_ value: Int) -> String {
        count.replacingOccurrences(of: "{count}", with: String(value))
    }

    func prText(_ number: Int) -> String {
        pr.replacingOccurrences(of: "{number}", with: String(number))
    }
}

nonisolated struct PublicReleaseNote: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let version: String
    let date: String
    let pr: Int
    let url: String
    let category: String
    let areas: [String]
    let title: String
    let summary: String
    let changes: [String]

    var externalURL: URL? {
        guard let url = URL(string: url), url.scheme?.lowercased() == "https" else { return nil }
        return url
    }
}

nonisolated enum PublicContentLocaleResolver {
    static func locale(
        languageCode: String,
        preferredLanguages: [String] = Locale.preferredLanguages
    ) -> String {
        AppLocalization.supportedLocale(
            languageCode: languageCode,
            preferredLanguages: preferredLanguages
        ).identifier
    }
}

nonisolated enum PublicContentTone: Equatable, Sendable {
    case accent
    case success
    case warning
    case danger
    case neutral
}

nonisolated struct PublicContentSymbol: Equatable, Sendable {
    let symbol: String
    let tone: PublicContentTone
}

nonisolated enum PublicContentPresentation {
    static func guideSection(id: String) -> PublicContentSymbol {
        switch id.lowercased() {
        case "dashboard", "home": .init(symbol: "house.fill", tone: .accent)
        case "calendar": .init(symbol: "calendar", tone: .success)
        case "team": .init(symbol: "building.2.fill", tone: .accent)
        case "friends": .init(symbol: "person.badge.plus", tone: .warning)
        case "settings": .init(symbol: "gearshape.fill", tone: .neutral)
        default: .init(symbol: "book.closed.fill", tone: .accent)
        }
    }

    static func guideCard(id: String) -> PublicContentSymbol {
        switch id.lowercased() {
        case "today", "calendar": .init(symbol: "calendar", tone: .accent)
        case "friends", "together", "staff": .init(symbol: "person.2.fill", tone: .neutral)
        case "duty": .init(symbol: "pencil", tone: .warning)
        case "excel": .init(symbol: "tablecells", tone: .success)
        case "schedule", "add": .init(symbol: "plus.circle.fill", tone: .accent)
        case "ai": .init(symbol: "sparkles", tone: .accent)
        case "visibility": .init(symbol: "eye.fill", tone: .success)
        case "dday": .init(symbol: "calendar.badge.clock", tone: .accent)
        case "todo": .init(symbol: "checklist", tone: .accent)
        case "search": .init(symbol: "magnifyingglass", tone: .neutral)
        case "others": .init(symbol: "person.badge.plus", tone: .accent)
        case "members": .init(symbol: "person.crop.circle.badge.checkmark", tone: .accent)
        case "dutytypes", "theme": .init(symbol: "paintpalette.fill", tone: .warning)
        case "requests": .init(symbol: "bell.badge.fill", tone: .danger)
        case "family": .init(symbol: "house.fill", tone: .warning)
        case "pinning": .init(symbol: "pin.fill", tone: .warning)
        case "remove": .init(symbol: "trash.fill", tone: .danger)
        case "photo": .init(symbol: "camera.fill", tone: .accent)
        case "delegation": .init(symbol: "shield.checkered", tone: .success)
        case "sessions": .init(symbol: "iphone", tone: .accent)
        case "social": .init(symbol: "link", tone: .warning)
        case "password": .init(symbol: "lock.fill", tone: .neutral)
        default: .init(symbol: "info.circle.fill", tone: .neutral)
        }
    }

    static func releaseCategory(_ category: String) -> PublicContentSymbol {
        switch category.lowercased() {
        case "feature": .init(symbol: "sparkles", tone: .accent)
        case "improvement": .init(symbol: "arrow.up.right.circle.fill", tone: .success)
        case "fix": .init(symbol: "wrench.and.screwdriver.fill", tone: .danger)
        case "security": .init(symbol: "lock.shield", tone: .warning)
        case "maintenance": .init(symbol: "gearshape.2.fill", tone: .neutral)
        default: .init(symbol: "doc.text.fill", tone: .neutral)
        }
    }
}
