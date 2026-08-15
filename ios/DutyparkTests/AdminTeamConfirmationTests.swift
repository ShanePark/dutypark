import Testing
@testable import Dutypark

@Suite("Admin team confirmation")
struct AdminTeamConfirmationTests {
    @Test("Team deletion confirmation blocks duplicate submissions while working")
    func deleteSubmissionPolicy() {
        #expect(AdminTeamDeleteConfirmationPolicy.canSubmit(isDeleting: false))
        #expect(!AdminTeamDeleteConfirmationPolicy.canSubmit(isDeleting: true))
    }
}
