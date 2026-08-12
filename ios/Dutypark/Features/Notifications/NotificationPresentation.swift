import Foundation

nonisolated enum NotificationRoute: Equatable, Hashable, Sendable {
    case friends
    case schedule(ScheduleID)
    case taggedSchedule(ScheduleID)
    case todo(TodoID?)
    case member(MemberID)

    init?(notification: NotificationDTO) {
        switch notification.referenceType {
        case .friendRequest:
            self = .friends
        case .schedule:
            guard let value = notification.referenceId, let id = UUID(uuidString: value) else { return nil }
            self = notification.type == .scheduleTagged ? .taggedSchedule(id) : .schedule(id)
        case .todo:
            self = .todo(notification.referenceId.flatMap(UUID.init(uuidString:)))
        case .member:
            guard let value = notification.referenceId, let id = Int64(value) else { return nil }
            self = .member(id)
        case .unknown, nil:
            return nil
        }
    }
}

nonisolated enum NotificationPresentation {
    static func message(for notification: NotificationDTO) -> String {
        guard notification.payload.version == 1 else {
            return String(localized: "notifications.items.generic", table: "Notifications")
        }

        let actorName = notification.payload.actor?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let actor = actorName?.isEmpty == false ? actorName : nil

        switch notification.type {
        case .friendRequestReceived:
            return actorMessage(
                actor,
                key: "notifications.items.friendRequestReceived",
                fallbackKey: "notifications.items.friendRequestReceivedFallback"
            )
        case .friendRequestAccepted:
            return actorMessage(
                actor,
                key: "notifications.items.friendRequestAccepted",
                fallbackKey: "notifications.items.friendRequestAcceptedFallback"
            )
        case .familyRequestReceived:
            return actorMessage(
                actor,
                key: "notifications.items.familyRequestReceived",
                fallbackKey: "notifications.items.familyRequestReceivedFallback"
            )
        case .familyRequestAccepted:
            return actorMessage(
                actor,
                key: "notifications.items.familyRequestAccepted",
                fallbackKey: "notifications.items.familyRequestAcceptedFallback"
            )
        case .scheduleTagged:
            return titledMessage(
                actor: actor,
                title: notification.payload.scheduleTitle ?? "",
                key: "notifications.items.scheduleTagged",
                fallbackKey: "notifications.items.scheduleTaggedFallback"
            )
        case .todoTagged:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoTagged",
                fallbackKey: "notifications.items.todoTaggedFallback"
            )
        case .todoStatusTodo:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoStatusTodo",
                fallbackKey: "notifications.items.todoStatusTodoFallback"
            )
        case .todoStatusInProgress:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoStatusInProgress",
                fallbackKey: "notifications.items.todoStatusInProgressFallback"
            )
        case .todoStatusDone:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoStatusDone",
                fallbackKey: "notifications.items.todoStatusDoneFallback"
            )
        case .unknown:
            return String(localized: "notifications.items.generic", table: "Notifications")
        }
    }

    static func date(from value: LocalDateTimeValue) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = value.rawValue.contains(".") ? "yyyy-MM-dd'T'HH:mm:ss.SSSSSS" : "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value.rawValue)
    }

    private static func actorMessage(_ actor: String?, key: String, fallbackKey: String) -> String {
        guard let actor else {
            return localized(fallbackKey)
        }
        return String(format: localized(key), locale: .current, actor)
    }

    private static func titledMessage(
        actor: String?,
        title: String,
        key: String,
        fallbackKey: String
    ) -> String {
        guard let actor else {
            return String(format: localized(fallbackKey), locale: .current, title)
        }
        return String(format: localized(key), locale: .current, actor, title)
    }

    private static func localized(_ key: String) -> String {
        String(localized: String.LocalizationValue(key), table: "Notifications")
    }
}
