import Foundation
import XCTest
@testable import Dutypark

/// Layout invariants of the friend tag selector that live only in the view body.
/// They are asserted against the source in the same idiom as
/// `DragFeedbackTests.testEveryDragSurfaceUsesTheSharedFeedbackModifier`, because a
/// SwiftUI body offers nothing else to inspect from a unit test.
final class DPFriendTagSelectorLayoutTests: XCTestCase {

    func testEveryRailCardSpendsTheTeamLineEvenWithoutATeam() throws {
        let source = try Self.selectorSource()

        XCTAssertFalse(
            source.contains("if let team = item.team"),
            "Dropping the team line for a team-less friend makes that card shorter than its neighbours"
        )
        XCTAssertTrue(
            source.contains("Text(teamLine(item))"),
            "The card must render the team line unconditionally so every card keeps the same height"
        )
    }

    /// The blank slot has to be reserved space, not fallback copy, and `Text("")`
    /// collapses to zero height — so the empty line needs a real character.
    func testABlankTeamLineReservesItsHeightWithoutInventingCopy() throws {
        let source = try Self.selectorSource()

        XCTAssertTrue(
            source.contains("\\u{00A0}"),
            "A blank team line must use a non-collapsing character to keep its line height"
        )
        XCTAssertFalse(
            source.contains("Text(item.team ?? \"\")"),
            "An empty string collapses the line and the card loses the reserved slot"
        )
    }

    func testTheRailHangsEveryCardFromASharedTopEdge() throws {
        let source = try Self.selectorSource()

        XCTAssertTrue(
            source.contains("LazyHStack(alignment: .top"),
            "A centred rail re-centres cards against each other instead of lining up their portraits"
        )
    }

    /// The reserved blank line is decoration, so the card's spoken label must keep
    /// naming only the friend and a team they actually have.
    func testABlankTeamLineStaysOutOfTheSpokenLabel() throws {
        let source = try Self.selectorSource()

        XCTAssertTrue(
            source.contains("accessibilityLabel(item.team.map { \"\\(item.name), \\($0)\" } ?? item.name)"),
            "VoiceOver must not read the blank team slot"
        )
    }

    func testSelectedFriendsGrowBelowTheRailInsteadOfPushingItDown() throws {
        let body = try Self.expandedSelectorBody()

        let search = try XCTUnwrap(body.range(of: "searchField"), "The expanded selector must still show the search field")
        let rail = try XCTUnwrap(body.range(of: "railItems.isEmpty"), "The expanded selector must still show the rail")
        let strip = try XCTUnwrap(body.range(of: "selectedStrip"), "The expanded selector must still show the selected friends")

        XCTAssertTrue(
            search.lowerBound < strip.lowerBound,
            "The selected friends belong under the search field, not above it"
        )
        XCTAssertTrue(
            rail.lowerBound < strip.lowerBound,
            "The selected friends must grow below the rail instead of pushing it down"
        )
    }

    func testTheSelectedStripStaysConditionalOnHavingASelection() throws {
        let body = try Self.expandedSelectorBody()

        XCTAssertTrue(
            body.contains("if !selectedItems.isEmpty"),
            "An empty selection must not leave an empty strip behind"
        )
    }

    /// `minimumScaleFactor` shrinks the line box along with the glyphs, so a card
    /// carrying a long name or team name ends up shorter than its neighbours — the
    /// same defect the reserved blank line exists to prevent. The home friend rail
    /// is held to this rule too, in `HomeDashboardTests`.
    func testNoCardLineShrinksItsTextToFit() throws {
        let card = try Self.cardBody()

        XCTAssertFalse(
            card.contains(".minimumScaleFactor("),
            "Shrinking a line shrinks its line box, so the card no longer matches the rest of the rail"
        )
        XCTAssertEqual(
            card.components(separatedBy: "lineLimit(1)").count - 1,
            2,
            "Both the name and the team line must truncate instead, on exactly one line each"
        )
    }

    /// Two rails drawing the same card from two sets of numbers is how they drift apart.
    func testBothPortraitRailsSizeTheirCardsFromTheSameBounds() throws {
        let source = try Self.selectorSource()
        let home = try Self.homeSource()

        XCTAssertTrue(
            source.contains("static let minimumCardWidth: CGFloat = 60")
                && source.contains("static let maximumCardWidth: CGFloat = 88"),
            "The shared card bounds belong beside the shared width formula"
        )
        XCTAssertTrue(
            home.contains("DPFriendTagSelectionLogic.minimumCardWidth")
                && home.contains("DPFriendTagSelectionLogic.maximumCardWidth"),
            "The home rail must take its card bounds from the shared ones, not restate them"
        )
    }

    private static func cardBody() throws -> Substring {
        let source = try selectorSource()
        let start = try XCTUnwrap(source.range(of: "private func card(_ item: DPFriendTagItem)"))
        let end = try XCTUnwrap(source.range(of: "private func teamLine("))
        return source[start.upperBound..<end.lowerBound]
    }

    private static func homeSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Features/Home/HomeView.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    private static func expandedSelectorBody() throws -> Substring {
        let source = try selectorSource()
        let start = try XCTUnwrap(source.range(of: "private var expandedSelector: some View {"))
        let end = try XCTUnwrap(source.range(of: "private var selectedStrip: some View {"))
        return source[start.upperBound..<end.lowerBound]
    }

    private static func selectorSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appending(path: "Dutypark/Components/DPFriendTagSelector.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }
}
