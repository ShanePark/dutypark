import Foundation
import Testing
@testable import Dutypark

struct TodoMemberTagTests {
    @Test
    func aSharedTodoTagsWhoeverTaggedYouIntoIt() {
        let tagger = MemberPreviewDTO(
            id: 7,
            name: "박태호",
            teamId: nil,
            team: nil,
            hasProfilePhoto: true,
            profilePhotoVersion: 3
        )
        let items = TodoMemberTagAdapter.items(of: makeTodo(
            isTagged: true,
            owner: "박태호",
            taggedByMember: tagger
        ))

        #expect(items == [
            DPMemberTagItem(memberID: 7, name: "박태호", hasProfilePhoto: true, profilePhotoVersion: 3)
        ])
    }

    // The owner's name is all an older shared to-do remembers, so the tag keeps the
    // name and goes without a face rather than disappearing.
    @Test
    func aSharedTodoWithoutAMemberFallsBackToTheOwnersName() {
        let items = TodoMemberTagAdapter.items(of: makeTodo(
            isTagged: true,
            owner: "박태호",
            taggedByMember: nil
        ))

        #expect(items == [DPMemberTagItem(memberID: nil, name: "박태호")])
        #expect(items.first?.hasProfilePhoto == false)
    }

    @Test
    func yourOwnTodoTagsEveryFriendYouTaggedInOrder() {
        let items = TodoMemberTagAdapter.items(of: makeTodo(
            isTagged: false,
            owner: "나",
            tags: [
                MemberPreviewDTO(
                    id: 1,
                    name: "김하나",
                    teamId: nil,
                    team: nil,
                    hasProfilePhoto: true,
                    profilePhotoVersion: 2
                ),
                MemberPreviewDTO(
                    id: 2,
                    name: "이두리",
                    teamId: nil,
                    team: "안전팀",
                    hasProfilePhoto: false,
                    profilePhotoVersion: 0
                ),
            ]
        ))

        #expect(items == [
            DPMemberTagItem(memberID: 1, name: "김하나", hasProfilePhoto: true, profilePhotoVersion: 2),
            DPMemberTagItem(memberID: 2, name: "이두리"),
        ])
    }

    @Test
    func anUntaggedTodoNamesNobody() {
        #expect(TodoMemberTagAdapter.items(of: makeTodo(isTagged: false, owner: "나")).isEmpty)
    }

    @Test
    func theMoreControlIsTranslatedInBothLanguages() {
        #expect(todoLocalized("todo.action.more", locale: Locale(identifier: "ko")) == "더보기")
        #expect(todoLocalized("todo.action.more", locale: Locale(identifier: "en")) == "More")
    }

    // Untagging and reporting are rare next to editing, so the detail row keeps them
    // behind one overflow control instead of spending two slots on them.
    @Test
    func untaggingAndReportingLiveBehindTheOverflowMenu() throws {
        let source = try source(of: "Dutypark/Features/Todo/TodoModalViews.swift")

        let menu = try #require(source.range(of: #"Image(systemName: "ellipsis")"#))
        let menuBody = String(source[source.startIndex..<menu.lowerBound])
        for wiring in [
            #"Label(todoLocalized("todo.action.leaveTag"), systemImage: "xmark")"#,
            "Text(todoLocalized(\"todo.action.report\"))",
            "DPReportBeaconIcon()",
            "Button(role: .destructive) {",
            #"accessibilityIdentifier("todo.detail.report")"#,
        ] {
            #expect(menuBody.contains(wiring), "The overflow menu is missing: \(wiring)")
        }

        #expect(!source.contains(#"systemImage: "flag""#), "Reporting is raised with a beacon, not a flag")
        #expect(
            !source.contains("TodoModalBorderedAction(\n                title: todoLocalized(\"todo.action.report\")"),
            "Reporting must not sit inline beside the other actions"
        )
    }

    private func source(of relativePath: String) throws -> String {
        let projectRoot = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(contentsOf: projectRoot.appending(path: relativePath), encoding: .utf8)
    }

    private func makeTodo(
        isTagged: Bool,
        owner: String,
        taggedByMember: MemberPreviewDTO? = nil,
        tags: [MemberPreviewDTO] = []
    ) -> TodoDTO {
        TodoDTO(
            id: UUID().uuidString,
            title: "장보기",
            content: "",
            position: 0,
            status: .todo,
            createdDate: LocalDateTimeValue(rawValue: "2026-08-20T10:00:00"),
            completedDate: nil,
            dueDate: nil,
            isOverdue: false,
            isTagged: isTagged,
            owner: owner,
            taggedByMember: taggedByMember,
            tags: tags,
            hasAttachments: false
        )
    }
}
