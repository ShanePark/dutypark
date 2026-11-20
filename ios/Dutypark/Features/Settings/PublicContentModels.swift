import Foundation

nonisolated protocol PublicContentEnvelope: Decodable, Sendable {
    var schemaVersion: Int { get }
}

nonisolated struct PublicBannedWords: PublicContentEnvelope, Equatable {
    let schemaVersion: Int
    let contentVersion: String
    let words: [String]
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
    let icon: String
    let tone: String
    let cards: [PublicGuideCard]
}

nonisolated struct PublicGuideCard: Decodable, Equatable, Identifiable, Sendable {
    let id: String
    let title: String
    let icon: String
    let tone: String
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

/// Raw values are the server's tone vocabulary keys; both clients share the same closed set.
nonisolated enum PublicContentTone: String, Equatable, Sendable {
    case accent
    case accentLight
    case success
    case warning
    case danger
    case neutral
    case muted
}

nonisolated struct PublicContentSymbol: Equatable, Sendable {
    let symbol: String
    let tone: PublicContentTone
}

nonisolated enum PublicContentPresentation {
    static let fallbackSymbol = "book.closed.fill"

    /// The design vocabulary shared with the web client. It changes only when the vocabulary
    /// itself changes - guide content changes ship in the canonical content file alone.
    private static let guideSymbols: [String: String] = [
        "home": "house.fill",
        "calendar": "calendar",
        "calendarCheck": "calendar.badge.clock",
        "building": "building.2.fill",
        "settings": "gearshape.fill",
        "users": "person.2.fill",
        "personAdd": "person.badge.plus",
        "userCog": "person.crop.circle.badge.checkmark",
        "pencil": "pencil",
        "spreadsheet": "tablecells",
        "plus": "plus.circle.fill",
        "sparkles": "sparkles",
        "eye": "eye.fill",
        "checklist": "checklist",
        "search": "magnifyingglass",
        "palette": "paintpalette.fill",
        "sun": "sun.max.fill",
        "bell": "bell.badge.fill",
        "pin": "pin.fill",
        "trash": "trash.fill",
        "camera": "camera.fill",
        "shield": "shield.checkered",
        "phone": "iphone",
        "link": "link",
        "lock": "lock.fill",
    ]

    static func symbol(icon: String) -> String {
        guideSymbols[icon] ?? fallbackSymbol
    }

    static func tone(_ tone: String) -> PublicContentTone {
        PublicContentTone(rawValue: tone) ?? .neutral
    }

    static func guideVisual(icon: String, tone: String) -> PublicContentSymbol {
        PublicContentSymbol(symbol: symbol(icon: icon), tone: self.tone(tone))
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

#if DEBUG
extension PublicGuideContent {
    static func uiTestingFixture(locale: String) -> PublicGuideContent {
        PublicGuideContent(
            schemaVersion: 1,
            contentVersion: "ui-testing",
            locale: locale,
            title: "이용 안내",
            description: "Dutypark의 주요 기능과 사용 방법을 안내합니다.",
            footer: "더 궁금한 점이 있으면 더보기 > 문의·지원으로 문의해주세요.",
            actions: PublicGuideActions(expandAll: "모두 펼치기", collapseAll: "모두 접기"),
            sections: [
                PublicGuideSection(
                    id: "start",
                    title: "시작하기",
                    summary: "Dutypark는 근무표와 일정, 할 일을 친구·가족·팀과 함께 관리하는 캘린더입니다.",
                    icon: "phone",
                    tone: "accent",
                    cards: [
                        PublicGuideCard(
                            id: "login",
                            title: "로그인과 가입",
                            icon: "lock",
                            tone: "neutral",
                            items: ["카카오, 네이버, Apple 계정으로 로그인합니다."]
                        )
                    ]
                )
            ]
        )
    }
}
#endif
