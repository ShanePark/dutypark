import Foundation
import Testing
@testable import Dutypark

@Suite("Admin team confirmation")
struct AdminTeamConfirmationTests {
    @Test("Team deletion is exposed only for a service-admin empty-team destination")
    @MainActor
    func deleteVisibilityPolicy() {
        #expect(DPSize.minimumTouchTarget == 44)
        #expect(
            TeamManageDeletePolicy.canShow(
                isServiceAdmin: true,
                hasMembers: false,
                hasDeleteAction: true
            )
        )
        #expect(
            !TeamManageDeletePolicy.canShow(
                isServiceAdmin: false,
                hasMembers: false,
                hasDeleteAction: true
            )
        )
        #expect(
            !TeamManageDeletePolicy.canShow(
                isServiceAdmin: true,
                hasMembers: true,
                hasDeleteAction: true
            )
        )
        #expect(
            !TeamManageDeletePolicy.canShow(
                isServiceAdmin: true,
                hasMembers: false,
                hasDeleteAction: false
            )
        )
    }

    @Test("Admin team list delegates deletion to the management destination")
    func listDeletionAffordance() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Admin/AdminTeamView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(!source.contains(".swipeActions("))
        #expect(source.contains("onDeleteTeam: { team in"))
        #expect(source.contains("try await model.delete("))
    }

    @Test("Only service admins can delete empty teams from the management header")
    func managementDeletionAffordance() throws {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Team/TeamManageView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        #expect(source.contains("onDeleteTeam: ((TeamDTO) async throws -> Void)?"))
        #expect(source.contains("viewModel.isServiceAdmin"))
        #expect(source.contains("team.members.isEmpty"))
        #expect(source.contains("present(.deleteTeam(team))"))
        #expect(source.contains(".accessibilityIdentifier(\"team.manage.delete\")"))
        #expect(source.contains("case .deleteTeam(let team):"))
        #expect(source.contains("team.manage.messages.deleteTeamConfirm"))
        #expect(source.contains("await deleteTeam(team)"))
    }
}
