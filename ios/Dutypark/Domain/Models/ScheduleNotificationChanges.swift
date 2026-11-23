import Foundation

nonisolated struct ScheduleTextChangeDTO: Codable, Equatable, Sendable {
    let before: String
    let after: String

    var changedPortions: [ScheduleTextChangeDTO] {
        let originalOld = Array(before)
        let originalNew = Array(after)
        let commonLimit = min(originalOld.count, originalNew.count)
        var prefix = 0
        while prefix < commonLimit, originalOld[prefix] == originalNew[prefix] {
            prefix += 1
        }
        var suffix = 0
        while suffix < commonLimit - prefix,
              originalOld[originalOld.count - suffix - 1] == originalNew[originalNew.count - suffix - 1] {
            suffix += 1
        }
        let old = Array(originalOld[prefix..<(originalOld.count - suffix)])
        let new = Array(originalNew[prefix..<(originalNew.count - suffix)])
        // Bound exact comparison work on large rewrites while keeping every changed character accessible.
        if old.count + new.count > 4_000 || old.count * new.count > 1_000_000 {
            return [ScheduleTextChangeDTO(before: String(old), after: String(new))]
        }
        let difference = new.difference(from: old)
        var removedOffsets = Set<Int>()
        var insertedOffsets = Set<Int>()
        for change in difference {
            switch change {
            case .remove(let offset, _, _): removedOffsets.insert(offset)
            case .insert(let offset, _, _): insertedOffsets.insert(offset)
            }
        }

        var oldIndex = 0
        var newIndex = 0
        var portions: [ScheduleTextChangeDTO] = []
        var shared = ""
        while oldIndex < old.count || newIndex < new.count {
            var removed = ""
            var inserted = ""
            while removedOffsets.contains(oldIndex) {
                removed.append(old[oldIndex])
                oldIndex += 1
            }
            while insertedOffsets.contains(newIndex) {
                inserted.append(new[newIndex])
                newIndex += 1
            }
            if !removed.isEmpty || !inserted.isEmpty {
                if !shared.isEmpty, shared.allSatisfy({ $0.isWhitespace }), let previous = portions.popLast() {
                    portions.append(ScheduleTextChangeDTO(
                        before: previous.before + shared + removed,
                        after: previous.after + shared + inserted
                    ))
                } else {
                    portions.append(ScheduleTextChangeDTO(before: removed, after: inserted))
                }
                shared = ""
            } else {
                shared.append(old[oldIndex])
                oldIndex += 1
                newIndex += 1
            }
        }
        return portions
    }
}

nonisolated struct ScheduleNotificationChangesDTO: Codable, Equatable, Sendable {
    struct TimeRange: Codable, Equatable, Sendable {
        let startDateTime: LocalDateTimeValue
        let endDateTime: LocalDateTimeValue
    }

    struct TimeChange: Codable, Equatable, Sendable {
        let before: TimeRange
        let after: TimeRange
    }

    let scheduleId: ScheduleID
    let scheduleVersion: Int64
    let scheduleTitle: String?
    let title: ScheduleTextChangeDTO?
    let description: ScheduleTextChangeDTO?
    let time: TimeChange?
}
