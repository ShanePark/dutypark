import Foundation
import Testing
@testable import Dutypark

@MainActor
@Suite
struct TodoDraftDirtyStateTests {
    @Test
    func inactiveDueDateDifferenceDoesNotMakeDraftDirty() {
        let initial = TodoDraft(status: .inProgress)
        var draft = initial
        draft.dueDate = initial.dueDate.addingTimeInterval(86_400)

        #expect(!isDirty(initial: initial, draft: draft))
    }

    @Test
    func activeDueDateDifferenceMakesDraftDirty() {
        var initial = TodoDraft(status: .inProgress)
        initial.hasDueDate = true
        var draft = initial
        draft.dueDate = initial.dueDate.addingTimeInterval(86_400)

        #expect(isDirty(initial: initial, draft: draft))
    }

    /// The date field speaks calendar days. Picking the day the draft already holds closes the
    /// calendar but must not move the stored instant, or an untouched form would read as dirty.
    @Test
    func pickingTheSameDueDayLeavesTheDraftUnchanged() {
        var initial = TodoDraft(status: .inProgress)
        initial.hasDueDate = true
        var draft = initial

        draft.dueDay = initial.dueDay

        #expect(draft == initial)
        #expect(!isDirty(initial: initial, draft: draft))
    }

    @Test
    func pickingADueDayIsWhatTheRequestSends() {
        var draft = TodoDraft(status: .inProgress)
        draft.hasDueDate = true

        draft.dueDay = DateOnly(rawValue: "2026-08-24")

        #expect(draft.dueDay == DateOnly(rawValue: "2026-08-24"))
        #expect(draft.request().dueDate == DateOnly(rawValue: "2026-08-24"))
    }

    @Test
    func editableFieldDifferencesMakeDraftDirty() {
        let initial = TodoDraft(status: .inProgress)

        var title = initial
        title.title = "Changed"
        #expect(isDirty(initial: initial, draft: title))

        var content = initial
        content.content = "Changed"
        #expect(isDirty(initial: initial, draft: content))

        var status = initial
        status.status = .done
        #expect(isDirty(initial: initial, draft: status))

        var tags = initial
        tags.taggedFriendIDs = [42]
        #expect(isDirty(initial: initial, draft: tags))
    }

    private func isDirty(initial: TodoDraft, draft: TodoDraft) -> Bool {
        TodoFormDismissalPolicy.isDirty(
            initialDraft: initial,
            draft: draft,
            initialAttachmentIDs: [],
            attachmentIDs: [],
            hasAttachmentSession: false
        )
    }
}
