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
    static func message(
        for notification: NotificationDTO,
        locale: Locale = AppLocalization.locale
    ) -> String {
        guard notification.payload.version == 1 else {
            return localized("notifications.items.generic", locale: locale)
        }

        let actorName = notification.payload.actor?.name?.trimmingCharacters(in: .whitespacesAndNewlines)
        let actor = actorName?.isEmpty == false ? actorName : nil

        switch notification.type {
        case .friendRequestReceived:
            return actorMessage(
                actor,
                key: "notifications.items.friendRequestReceived",
                fallbackKey: "notifications.items.friendRequestReceivedFallback",
                locale: locale
            )
        case .friendRequestAccepted:
            return actorMessage(
                actor,
                key: "notifications.items.friendRequestAccepted",
                fallbackKey: "notifications.items.friendRequestAcceptedFallback",
                locale: locale
            )
        case .familyRequestReceived:
            return actorMessage(
                actor,
                key: "notifications.items.familyRequestReceived",
                fallbackKey: "notifications.items.familyRequestReceivedFallback",
                locale: locale
            )
        case .familyRequestAccepted:
            return actorMessage(
                actor,
                key: "notifications.items.familyRequestAccepted",
                fallbackKey: "notifications.items.familyRequestAcceptedFallback",
                locale: locale
            )
        case .scheduleTagged:
            return titledMessage(
                actor: actor,
                title: notification.payload.scheduleTitle ?? "",
                key: "notifications.items.scheduleTagged",
                fallbackKey: "notifications.items.scheduleTaggedFallback",
                locale: locale
            )
        case .todoTagged:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoTagged",
                fallbackKey: "notifications.items.todoTaggedFallback",
                locale: locale
            )
        case .todoStatusTodo:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoStatusTodo",
                fallbackKey: "notifications.items.todoStatusTodoFallback",
                locale: locale
            )
        case .todoStatusInProgress:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoStatusInProgress",
                fallbackKey: "notifications.items.todoStatusInProgressFallback",
                locale: locale
            )
        case .todoStatusDone:
            return titledMessage(
                actor: actor,
                title: notification.payload.todoTitle ?? "",
                key: "notifications.items.todoStatusDone",
                fallbackKey: "notifications.items.todoStatusDoneFallback",
                locale: locale
            )
        case .unknown:
            return localized("notifications.items.generic", locale: locale)
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

    /// Matches the locale-specific absolute timestamp shown beside relative time on the web list.
    static func absoluteDate(
        _ date: Date,
        locale: Locale = AppLocalization.locale,
        timeZone: TimeZone = .current
    ) -> String {
        let identifier = locale.identifier.lowercased()
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = locale
        formatter.timeZone = timeZone

        if identifier.hasPrefix("en") {
            formatter.dateFormat = "MMM d, yyyy HH:mm"
        } else if identifier.hasPrefix("ja") {
            formatter.dateFormat = "yyyy/MM/dd HH:mm"
        } else if identifier.hasPrefix("es") {
            formatter.dateFormat = "d MMM yyyy HH:mm"
        } else if identifier.hasPrefix("zh") {
            formatter.dateFormat = "yyyy年M月d日 HH:mm"
        } else {
            formatter.dateFormat = "yyyy.MM.dd HH:mm"
        }
        return formatter.string(from: date)
    }

    private static func actorMessage(
        _ actor: String?,
        key: String,
        fallbackKey: String,
        locale: Locale
    ) -> String {
        guard let actor else {
            return localized(fallbackKey, locale: locale)
        }
        return String(format: localized(key, locale: locale), locale: locale, actor)
    }

    private static func titledMessage(
        actor: String?,
        title: String,
        key: String,
        fallbackKey: String,
        locale: Locale
    ) -> String {
        guard let actor else {
            return String(format: localized(fallbackKey, locale: locale), locale: locale, title)
        }
        return String(format: localized(key, locale: locale), locale: locale, actor, title)
    }

    private static func localized(_ key: String, locale: Locale) -> String {
        AppLocalization.string(key, table: "Notifications", locale: locale)
    }
}
