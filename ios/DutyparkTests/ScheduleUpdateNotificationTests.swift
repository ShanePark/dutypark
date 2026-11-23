import Foundation
import Testing
@testable import Dutypark

@MainActor
struct ScheduleUpdateNotificationTests {
    @Test
    func updatedScheduleGoesDirectlyToScheduleAndFallsBackToChangedFieldSummary() throws {
        let id = UUID()
        let scheduleID = UUID()
        let data = Data("""
        {"id":"\(id)","type":"SCHEDULE_UPDATED","referenceType":"SCHEDULE","referenceId":"\(scheduleID)","actorId":2,"payload":{"version":1,"actor":{"name":"하나","hasProfilePhoto":false,"profilePhotoVersion":0},"scheduleVersion":3,"changedFields":["TITLE","TIME"]},"isRead":false,"createdAt":"2026-11-23T12:00:00"}
        """.utf8)
        let notification = try JSONDecoder().decode(NotificationDTO.self, from: data)
        #expect(notification.type == .scheduleUpdated)
        #expect(notification.payload.scheduleVersion == 3)
        #expect(NotificationRoute(notification: notification) == .taggedSchedule(scheduleID))
        let message = NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko"))
        #expect(message.contains("하나"))
        #expect(message.contains("제목"))
        #expect(message.contains("시간"))
        #expect(!message.contains("본문"))
    }

    @Test
    func bodyComparisonOmitsSharedPrefixAndSuffixAndPreservesUnicode() {
        let change = ScheduleTextChangeDTO(before: "공통 🍎 이전 본문 끝", after: "공통 🍎 새 본문 끝")
        #expect(change.changedPortions.first?.before == "이전")
        #expect(change.changedPortions.first?.after == "새")
        let insertion = ScheduleTextChangeDTO(before: "회의", after: "월간 회의")
        #expect(insertion.changedPortions.first?.before == "")
        #expect(insertion.changedPortions.first?.after == "월간 ")
    }

    @Test
    func bodyComparisonSeparatesDisjointChangesAndOmitsUnchangedMiddle() {
        let change = ScheduleTextChangeDTO(before: "가나다 SAME 라마바", after: "사아자 SAME 차카타")
        #expect(change.changedPortions == [
            ScheduleTextChangeDTO(before: "가나다", after: "사아자"),
            ScheduleTextChangeDTO(before: "라마바", after: "차카타"),
        ])
        #expect(ScheduleTextChangeDTO(before: "same", after: "same").changedPortions.isEmpty)
    }

    @Test
    func largeRewriteBoundsExactComparisonWithoutDroppingChangedContent() {
        let oldMiddle = String(repeating: "a", count: 32_768)
        let newMiddle = String(repeating: "b", count: 32_768)
        let change = ScheduleTextChangeDTO(
            before: "shared prefix " + oldMiddle + " shared suffix",
            after: "shared prefix " + newMiddle + " shared suffix"
        )
        #expect(change.changedPortions == [ScheduleTextChangeDTO(before: oldMiddle, after: newMiddle)])
    }

    @Test
    func scheduleChangeDetailDecodesOnlyChangedValues() throws {
        let data = Data("""
        {"scheduleId":"\(UUID())","scheduleVersion":4,"description":{"before":"기존 내용","after":"수정 내용"}}
        """.utf8)
        let changes = try JSONDecoder().decode(ScheduleNotificationChangesDTO.self, from: data)
        #expect(changes.title == nil)
        #expect(changes.time == nil)
        #expect(changes.description?.after == "수정 내용")
    }

    @Test
    func inlineDescriptionIncludesActualChangedTextAndDirectRoute() throws {
        let notification = try inlineNotification(before: "기존 ㄴㄴㄴ 본문", after: "기존 ㅇㅇㅇ 본문")
        #expect(NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko")) ==
                "박세현님이 일정을 수정했습니다.\n‘ㄴㄴㄴ’ → ‘ㅇㅇㅇ’")
        #expect(NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko"), accessibilityLabels: true)
            .contains("본문 ‘ㄴㄴㄴ’ → ‘ㅇㅇㅇ’"))
        #expect(NotificationRoute(notification: notification) == .taggedSchedule(UUID(uuidString: notification.referenceId!)!))
    }

    @Test
    func inlineMessageIncludesEveryChangedFieldAndEnglishLocalization() throws {
        let data = Data("""
        {"id":"\(UUID())","type":"SCHEDULE_UPDATED","referenceType":"SCHEDULE","referenceId":"\(UUID())","actorId":2,"payload":{"version":1,"actor":{"name":"Park","hasProfilePhoto":false,"profilePhotoVersion":0},"scheduleVersion":3,"changedFields":["TITLE","DESCRIPTION","TIME"]},"isRead":false,"createdAt":"2026-11-23T12:00:00","scheduleChanges":{"scheduleId":"\(UUID())","scheduleVersion":3,"title":{"before":"Old","after":"New"},"description":{"before":"a OLD b","after":"a NEW b"},"time":{"before":{"startDateTime":"2026-11-23T14:00:00","endDateTime":"2026-11-23T15:00:00"},"after":{"startDateTime":"2026-11-23T16:00:00","endDateTime":"2026-11-23T17:00:00"}}}}
        """.utf8)
        let notification = try JSONDecoder().decode(NotificationDTO.self, from: data)
        let message = NotificationPresentation.message(for: notification, locale: Locale(identifier: "en"))
        #expect(message == "Park renamed the ‘Old’ schedule to ‘New’.\n‘OLD’ → ‘NEW’\n14:00–15:00 → 16:00–17:00")
        #expect(!message.contains("a OLD b"))
    }

    @Test
    func inlinePreviewBoundsLengthAndNormalizesWhitespace() throws {
        let notification = try inlineNotification(
            before: String(repeating: "가", count: 180), after: String(repeating: "🍎", count: 180)
        )
        let message = NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko"))
        #expect(message.contains(String(repeating: "가", count: 100) + "…"))
        #expect(message.contains(String(repeating: "🍎", count: 100) + "…"))
        #expect(!message.contains(String(repeating: "🍎", count: 101)))
        let whitespace = try inlineNotification(before: "  old\n text  ", after: "  new\n value  ")
        let normalized = NotificationPresentation.message(for: whitespace, locale: Locale(identifier: "ko"))
        #expect(!normalized.contains("old\n text"))
    }

    @Test
    func disjointBodyChangesShareOneCompactFieldClause() throws {
        let notification = try inlineNotification(before: "가나다 SAME 라마바", after: "사아자 SAME 차카타")
        let message = NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko"))
        #expect(message == "박세현님이 일정을 수정했습니다.\n‘가나다 … 라마바’ → ‘사아자 … 차카타’")
        #expect(!message.contains("SAME"))
    }

    @Test
    func whitespaceOnlyMatchesStayInsideBodyChange() {
        #expect(ScheduleTextChangeDTO(before: "회의실 A", after: "화상 통화").changedPortions == [
            ScheduleTextChangeDTO(before: "회의실 A", after: "화상 통화")
        ])
    }

    @Test
    func pinnedScheduleTitleAppearsOnlyWhenTitleUnchanged() throws {
        let notification = try inlineNotification(before: "온라인", after: "대면", scheduleTitle: "알림 확인 · 일정 확정")
        #expect(NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko")) ==
            "박세현님이 ‘알림 확인 · 일정 확정’ 일정을 수정했습니다.\n‘온라인’ → ‘대면’")
    }

    @Test
    func timeChangesUseWallClockDatesAndOnlyNecessaryDateContext() throws {
        let cases: [(String, String, String, String, String)] = [
            ("2026-11-23T14:00:00", "2026-11-23T14:30:00", "2026-11-23T15:00:00", "2026-11-23T15:30:00", "14:00–14:30 → 15:00–15:30"),
            ("2026-11-23T14:00:00", "2026-11-23T14:30:00", "2026-11-24T15:00:00", "2026-11-24T15:30:00", "11/23 14:00–14:30 → 11/24 15:00–15:30"),
            ("2026-11-23T23:00:00", "2026-11-24T01:00:00", "2026-11-23T23:30:00", "2026-11-24T02:00:00", "11/23 23:00–11/24 01:00 → 11/23 23:30–11/24 02:00"),
            ("2026-12-31T23:00:00", "2027-01-01T01:00:00", "2027-01-01T15:00:00", "2027-01-01T15:30:00", "2026/12/31 23:00–2027/1/1 01:00 → 2027/1/1 15:00–15:30"),
        ]
        for (start, end, newStart, newEnd, expected) in cases {
            let base = try inlineNotification(before: "a", after: "b")
            var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
            object["scheduleChanges"] = [
                "scheduleId": UUID().uuidString, "scheduleVersion": 3,
                "time": ["before": ["startDateTime": start, "endDateTime": end],
                         "after": ["startDateTime": newStart, "endDateTime": newEnd]],
            ]
            let notification = try JSONDecoder().decode(NotificationDTO.self, from: JSONSerialization.data(withJSONObject: object))
            #expect(NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko")) ==
                    "박세현님이 일정을 수정했습니다.\n" + expected)
        }
    }

    @Test
    func titleRenameUsesOneNaturalHeadingAndKoreanParticles() throws {
        let cases = [("최종 회의", "로"), ("일정", "으로"), ("서울", "로"), ("회의실 0! ", "으로"),
                     ("회의실 3", "으로"), ("회의실 6", "으로"), ("회의실 1", "로"), ("Meeting", "로")]
        for (title, particle) in cases {
            let base = try inlineNotification(before: "a", after: "b")
            var object = try #require(JSONSerialization.jsonObject(with: JSONEncoder().encode(base)) as? [String: Any])
            object["scheduleChanges"] = ["scheduleId": UUID().uuidString, "scheduleVersion": 3,
                                         "scheduleTitle": title, "title": ["before": "자료 검토", "after": title]]
            let notification = try JSONDecoder().decode(NotificationDTO.self, from: JSONSerialization.data(withJSONObject: object))
            let shownTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
            #expect(NotificationPresentation.message(for: notification, locale: Locale(identifier: "ko")) ==
                    "박세현님이 ‘자료 검토’ 일정을 ‘\(shownTitle)’\(particle) 변경했습니다.")
        }
    }

    private func inlineNotification(before: String, after: String, scheduleTitle: String? = nil) throws -> NotificationDTO {
        let titleJSON = String(data: try JSONEncoder().encode(scheduleTitle), encoding: .utf8)!
        let beforeJSON = String(data: try JSONEncoder().encode(before), encoding: .utf8)!
        let afterJSON = String(data: try JSONEncoder().encode(after), encoding: .utf8)!
        let data = Data("""
        {"id":"\(UUID())","type":"SCHEDULE_UPDATED","referenceType":"SCHEDULE","referenceId":"\(UUID())","actorId":2,"payload":{"version":1,"actor":{"name":"박세현","hasProfilePhoto":false,"profilePhotoVersion":0},"scheduleVersion":3,"changedFields":["DESCRIPTION"]},"isRead":false,"createdAt":"2026-11-23T12:00:00","scheduleChanges":{"scheduleId":"\(UUID())","scheduleVersion":3,"scheduleTitle":\(titleJSON),"description":{"before":\(beforeJSON),"after":\(afterJSON)}}}
        """.utf8)
        return try JSONDecoder().decode(NotificationDTO.self, from: data)
    }
}
