import Foundation
import Testing
@testable import Dutypark

@MainActor
struct DomainContractDecodingTests {
    @Test
    func decodesMemberFromBackendShape() throws {
        let member: MemberDTO = try decodeFixture("member")

        #expect(member.id == 42)
        #expect(member.calendarVisibility == .friends)
        #expect(member.naverId == "naver-42")
        #expect(member.appleId == "apple-42")
        #expect(member.hasProfilePhoto)
    }

    @Test
    func preservesLocalDateTimesWithoutAssumingATimeZone() throws {
        let schedule: ScheduleDTO = try decodeFixture("schedule")

        #expect(schedule.startDateTime.rawValue == "2026-08-12T09:30:00.123456")
        #expect(schedule.totalDays == 2)
        #expect(schedule.attachments.first?.createdAt.hasSuffix("+09:00") == true)
    }

    @Test
    func decodesTodoBoardCountsAndNullableDates() throws {
        let board: TodoBoardDTO = try decodeFixture("todo-board")

        #expect(board.counts.total == 1)
        #expect(board.todo.first?.status == .todo)
        #expect(board.todo.first?.completedDate == nil)
    }

    @Test
    func decodesTeamDefaultDutyTypeWithNullableIdentifier() throws {
        let team: TeamDTO = try decodeFixture("team")

        #expect(team.dutyTypes.first?.id == nil)
        #expect(team.dutyTypes.first?.teamId == 7)
        #expect(team.members.first?.isManager == true)
    }

    @Test
    func decodesNullableCurrentPolicies() throws {
        let policies: CurrentPoliciesDTO = try decodeFixture("current-policies")

        #expect(policies.terms?.policyType == .terms)
        #expect(policies.privacy == nil)
    }

    @Test
    func decodesPagedVersionedNotificationPayload() throws {
        let page: PageResponse<NotificationDTO> = try decodeFixture("notification-page")

        #expect(page.totalElements == 1)
        #expect(page.content.first?.type == .scheduleTagged)
        #expect(page.content.first?.payload.scheduleTitle == "당직 후 저녁 약속")
    }

    @Test
    func decodesStructuredAPIErrorDetails() throws {
        let error: APIErrorResponse = try decodeFixture("api-error")

        #expect(error.code == "schedule.content.required")
        #expect(error.details?["attempt"] == .integer(2))
        #expect(error.fieldErrors.first?.field == "content")
    }

    @Test
    func keepsUnknownEnumValuesDecodable() throws {
        let duty = try JSONDecoder().decode(
            DutyDTO.self,
            from: Data("""
                {"year":2026,"month":8,"day":12,"dutyType":null,"dutyColor":null,"isOff":true,"dutyTypeId":null,"source":"FUTURE_SOURCE"}
                """.utf8)
        )

        #expect(duty.source == .unknown("FUTURE_SOURCE"))
    }

    private func decodeFixture<Value: Decodable>(_ name: String) throws -> Value {
        let bundle = Bundle(for: FixtureBundleToken.self)
        let url = try #require(
            bundle.url(forResource: name, withExtension: "json", subdirectory: "Fixtures")
                ?? bundle.url(forResource: name, withExtension: "json")
        )
        return try JSONDecoder().decode(Value.self, from: Data(contentsOf: url))
    }
}

private final class FixtureBundleToken {}
