import Foundation
import Testing
@testable import Dutypark

struct NotificationRouteRegressionTests {
    @Test
    func malformedTodoReferenceNeverDegradesIntoALegacyDestination() throws {
        let malformedTodo = try notification(referenceType: "TODO", referenceID: "not-a-uuid")

        #expect(NotificationRoute(notification: malformedTodo) == nil)
    }

    private func notification(
        referenceType: String,
        referenceID: String
    ) throws -> NotificationDTO {
        try JSONDecoder().decode(
            NotificationDTO.self,
            from: Data("""
                {
                  "id": "\(UUID().uuidString)",
                  "type": "TODO_STATUS_DONE",
                  "referenceType": "\(referenceType)",
                  "referenceId": "\(referenceID)",
                  "actorId": 11,
                  "payload": {"version": 1, "actor": null, "todoTitle": "Task"},
                  "isRead": false,
                  "createdAt": "2026-08-12T09:51:51.163702"
                }
                """.utf8)
        )
    }
}
