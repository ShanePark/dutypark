import SwiftUI

nonisolated enum NotificationRoute: Equatable, Hashable, Sendable {
    case friends
    case schedule(ScheduleID)
    case taggedSchedule(ScheduleID)
    case todo(TodoID?)
    case member(MemberID)
    case support

    init?(notification: NotificationDTO) {
        switch notification.referenceType {
        case .friendRequest:
            self = .friends
        case .schedule:
            guard let value = notification.referenceId, let id = UUID(uuidString: value) else { return nil }
            self = notification.type == .scheduleTagged || notification.type == .scheduleUpdated
                ? .taggedSchedule(id) : .schedule(id)
        case .todo:
            if let value = notification.referenceId {
                guard let id = UUID(uuidString: value) else { return nil }
                self = .todo(id)
            } else {
                self = .todo(nil)
            }
        case .member:
            guard let value = notification.referenceId, let id = Int64(value) else { return nil }
            self = .member(id)
        // The inquiry itself has no screen of its own: the answer is read in the
        // support screen's history tab, which loads the member's whole list.
        case .inquiry:
            self = .support
        case .unknown, nil:
            return nil
        }
    }
}

nonisolated enum NotificationPresentation {
    static func message(
        for notification: NotificationDTO,
        locale: Locale = AppLocalization.locale,
        accessibilityLabels: Bool = false
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
        case .scheduleUpdated:
            if let changes = notification.scheduleChanges,
               let message = scheduleChangeMessage(changes, actor: actor, locale: locale, accessibilityLabels: accessibilityLabels) {
                return message
            }
            let summary = actorMessage(
                actor,
                key: "notifications.items.scheduleUpdated",
                fallbackKey: "notifications.items.scheduleUpdatedFallback",
                locale: locale
            )
            let fields = notification.payload.changedFields.compactMap { field -> String? in
                let key: String
                switch field {
                case "TITLE": key = "notifications.changes.title"
                case "DESCRIPTION": key = "notifications.changes.description"
                case "TIME": key = "notifications.changes.time"
                default: return nil
                }
                return localized(key, locale: locale)
            }
            return fields.isEmpty ? summary : "\(summary) · \(fields.joined(separator: ", "))"
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
        case .inquiryAnswered:
            return subjectMessage(
                notification.payload.subject,
                key: "notifications.items.inquiryAnswered",
                fallbackKey: "notifications.items.inquiryAnsweredFallback",
                locale: locale
            )
        case .unknown:
            return localized("notifications.items.generic", locale: locale)
        }
    }

    private static func scheduleChangeMessage(
        _ changes: ScheduleNotificationChangesDTO, actor: String?, locale: Locale, accessibilityLabels: Bool
    ) -> String? {
        var lines: [String] = []
        func append(_ change: ScheduleTextChangeDTO, field: String) {
            let values = String(format: localized("notifications.changes.inlineClause", locale: locale),
                                locale: locale, compactValue(change.before, locale: locale),
                                compactValue(change.after, locale: locale))
            lines.append(accessibilityLabels ? "\(localized(field, locale: locale)) \(values)" : values)
        }
        if let description = changes.description {
            let portions = description.changedPortions
            if !portions.isEmpty {
                append(ScheduleTextChangeDTO(
                    before: portions.map(\.before).filter { !$0.isEmpty }.joined(separator: " … "),
                    after: portions.map(\.after).filter { !$0.isEmpty }.joined(separator: " … ")
                ), field: "notifications.changes.description")
            }
        }
        if let time = changes.time {
            let dates = [time.before.startDateTime, time.before.endDateTime,
                         time.after.startDateTime, time.after.endDateTime].map { String($0.rawValue.prefix(10)) }
            let includeDate = Set(dates).count > 1
            let includeYear = Set(dates.map { String($0.prefix(4)) }).count > 1
            let field = includeDate ? "notifications.changes.time" : "notifications.changes.timeOnly"
            let values = "\(timeRange(time.before, includeDate: includeDate, includeYear: includeYear)) → \(timeRange(time.after, includeDate: includeDate, includeYear: includeYear))"
            lines.append(accessibilityLabels ? "\(localized(field, locale: locale)) \(values)" : values)
        }
        guard changes.title != nil || !lines.isEmpty else { return nil }
        let heading: String
        if let title = changes.title {
            let before = compactValue(title.before, locale: locale)
            let after = compactValue(title.after, locale: locale)
            let suffix = koreanDirectionalParticle(title.after) == "으로" ? "Euro" : "Ro"
            if let actor {
                heading = String(format: localized("notifications.changes.renameHeading" + suffix, locale: locale),
                                 locale: locale, actor, before, after)
            } else {
                heading = String(format: localized("notifications.changes.renameHeadingFallback" + suffix, locale: locale),
                                 locale: locale, before, after)
            }
        } else if let title = changes.scheduleTitle,
           !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            heading = titledMessage(
                actor: actor, title: compactValue(title, locale: locale),
                key: "notifications.changes.titledHeading",
                fallbackKey: "notifications.changes.titledHeadingFallback", locale: locale
            )
        } else {
            heading = actorMessage(actor, key: "notifications.changes.heading",
                                   fallbackKey: "notifications.changes.headingFallback", locale: locale)
        }
        return ([heading] + lines).joined(separator: "\n")
    }

    private static func koreanDirectionalParticle(_ value: String) -> String {
        guard let ending = value.last(where: { $0.isLetter || $0.isNumber }) else { return "로" }
        if "036".contains(ending) { return "으로" }
        guard let scalar = ending.unicodeScalars.first?.value, (0xAC00...0xD7A3).contains(scalar) else { return "로" }
        let finalConsonant = (scalar - 0xAC00) % 28
        return finalConsonant == 0 || finalConsonant == 8 ? "로" : "으로"
    }

    private static func compactValue(_ value: String, locale: Locale) -> String {
        let normalized = value.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
        if normalized.isEmpty { return localized("notifications.changes.empty", locale: locale) }
        return normalized.count > 100 ? String(normalized.prefix(100)) + "…" : normalized
    }

    private static func timeRange(
        _ range: ScheduleNotificationChangesDTO.TimeRange, includeDate: Bool, includeYear: Bool
    ) -> String {
        func date(_ value: LocalDateTimeValue) -> String { String(value.rawValue.prefix(10)) }
        func stamp(_ value: LocalDateTimeValue, withDate: Bool) -> String {
            let raw = value.rawValue
            let clock = String(raw.dropFirst(11).prefix(5))
            guard withDate else { return clock }
            let pieces = date(value).split(separator: "-")
            guard pieces.count == 3, let month = Int(pieces[1]), let day = Int(pieces[2]) else {
                return "\(date(value)) \(clock)"
            }
            let prefix = includeYear ? "\(pieces[0])/" : ""
            return "\(prefix)\(month)/\(day) \(clock)"
        }
        // LocalDateTime is a wall-clock value; formatting must never apply a time-zone conversion.
        return "\(stamp(range.startDateTime, withDate: includeDate))–\(stamp(range.endDateTime, withDate: includeDate && date(range.startDateTime) != date(range.endDateTime)))"
    }

    static func date(from value: LocalDateTimeValue) -> Date? {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = value.rawValue.contains(".") ? "yyyy-MM-dd'T'HH:mm:ss.SSSSSS" : "yyyy-MM-dd'T'HH:mm:ss"
        return formatter.date(from: value.rawValue)
    }

    /// Formats the same single-unit relative time used by the web notification list.
    static func relativeTime(
        _ date: Date,
        now: Date = .now,
        locale: Locale = AppLocalization.locale
    ) -> String {
        let supportedLocale = AppLocalization.supportedLocale(
            languageCode: locale.identifier,
            preferredLanguages: []
        )
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = supportedLocale
        formatter.unitsStyle = .full
        formatter.dateTimeStyle = .numeric

        let interval = abs(date.timeIntervalSince(now))
        let direction = date <= now ? -1 : 1
        let seconds = Int(interval.rounded())
        let minutes = Int((interval / 60).rounded())
        let hours = Int((interval / 3_600).rounded())
        let days = Int((interval / 86_400).rounded())
        let months = Int((interval / (86_400 * 30.44)).rounded())
        let years = Int((interval / (86_400 * 365.25)).rounded())

        let components: DateComponents
        if seconds <= 44 {
            components = DateComponents(second: direction * max(1, seconds))
        } else if seconds <= 89 {
            components = DateComponents(minute: direction)
        } else if minutes <= 44 {
            components = DateComponents(minute: direction * max(1, minutes))
        } else if minutes <= 89 {
            components = DateComponents(hour: direction)
        } else if hours <= 21 {
            components = DateComponents(hour: direction * max(1, hours))
        } else if hours <= 35 {
            components = DateComponents(day: direction)
        } else if days <= 25 {
            components = DateComponents(day: direction * max(1, days))
        } else if days <= 45 {
            components = DateComponents(month: direction)
        } else if months <= 10 {
            components = DateComponents(month: direction * max(1, months))
        } else if months <= 17 {
            components = DateComponents(year: direction)
        } else {
            components = DateComponents(year: direction * max(1, years))
        }

        return formatter.localizedString(from: components)
    }

    /// Matches the locale-specific absolute timestamp shown beside relative time on the web list.
    static func absoluteDate(
        _ date: Date,
        locale: Locale = AppLocalization.locale,
        timeZone: TimeZone = .current
    ) -> String {
        let supportedLocale = AppLocalization.supportedLocale(
            languageCode: locale.identifier,
            preferredLanguages: []
        )
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = supportedLocale
        formatter.timeZone = timeZone

        if supportedLocale.identifier == "ko" {
            formatter.dateFormat = "yyyy.MM.dd HH:mm"
        } else {
            formatter.dateFormat = "MMM d, yyyy HH:mm"
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

    /// The answering administrator stays anonymous, so an inquiry message is built
    /// from its own subject instead of an actor name.
    private static func subjectMessage(
        _ subject: String?,
        key: String,
        fallbackKey: String,
        locale: Locale
    ) -> String {
        let trimmed = subject?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let trimmed, !trimmed.isEmpty else {
            return localized(fallbackKey, locale: locale)
        }
        return String(format: localized(key, locale: locale), locale: locale, trimmed)
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

struct NotificationRelativeTimeText: View {
    let date: Date

    @Environment(\.locale) private var locale

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { context in
            Text(NotificationPresentation.relativeTime(date, now: context.date, locale: locale))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
    }
}

struct NotificationMessageText: View {
    let notification: NotificationDTO
    let ordinaryLineLimit: Int

    @Environment(\.locale) private var locale

    var body: some View {
        let message = NotificationPresentation.message(for: notification, locale: locale)
        let lines = notification.type == .scheduleUpdated
            ? message.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
            : [Substring(message)]
        VStack(alignment: .leading, spacing: 4) {
            Text(String(lines[0]))
                .font(notification.isRead ? DPTypography.label : DPFont.bold(size: 14, relativeTo: .subheadline))
                .lineLimit(notification.type == .scheduleUpdated ? nil : ordinaryLineLimit)
            if notification.type == .scheduleUpdated, lines.count > 1 {
                Text(String(lines[1]))
                    .font(DPTypography.label)
                    .lineLimit(nil)
            }
        }
        .foregroundStyle(notification.isRead ? DPColor.textSecondary : DPColor.textPrimary)
        .multilineTextAlignment(.leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(NotificationPresentation.message(for: notification, locale: locale, accessibilityLabels: true))
    }
}
