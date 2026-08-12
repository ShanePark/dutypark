import Foundation

enum AppTab: String, CaseIterable, Identifiable, Sendable {
    case home
    case calendar
    case todo
    case team
    case settings

    nonisolated var id: Self { self }

    nonisolated var tabTitle: LocalizedStringResource {
        switch self {
        case .home:
            "tab.home"
        case .calendar:
            "tab.calendar"
        case .todo:
            "tab.todo"
        case .team:
            "tab.team"
        case .settings:
            "tab.settings"
        }
    }

    nonisolated var navigationTitle: LocalizedStringResource {
        switch self {
        case .home:
            "screen.home.title"
        case .calendar:
            "screen.calendar.title"
        case .todo:
            "screen.todo.title"
        case .team:
            "screen.team.title"
        case .settings:
            "screen.settings.title"
        }
    }

    nonisolated var systemImage: String {
        switch self {
        case .home:
            "house"
        case .calendar:
            "calendar"
        case .todo:
            "checklist"
        case .team:
            "person.2"
        case .settings:
            "gearshape"
        }
    }

    nonisolated var accessibilityIdentifier: String {
        "tab.\(rawValue)"
    }
}
