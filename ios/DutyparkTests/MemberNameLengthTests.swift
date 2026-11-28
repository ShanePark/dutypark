import Foundation
import SwiftUI
import Testing
import UIKit
@testable import Dutypark

/// Member names run to 20 UTF-16 units, and narrow slots fall back to initials only when
/// the full name overflows (docs/design/member-name-length.md).
struct MemberNameInitialsTests {
    /// The vectors the web's `memberInitials` shares.
    @Test(arguments: [
        ("Shane Park", "S.P"),
        ("Mary Jane Lee", "M.J.L"),
        ("shane park", "S.P"),
        ("  Shane   Park  ", "S.P"),
        ("Jean-Luc Picard", "J.P"),
        ("Élodie Durand", "É.D"),
    ])
    func latinNamesOfSeveralWordsHaveInitials(name: String, initials: String) {
        #expect(MemberNameInitials.initials(for: name) == initials)
    }

    @Test(arguments: ["Christopher", "박세현", "박 세현", "Shane 박", ""])
    func otherNamesHaveNoInitials(name: String) {
        #expect(MemberNameInitials.initials(for: name) == nil)
    }

    /// A decomposed "É" (E + combining acute) stays one letter.
    @Test
    func aDecomposedAccentStaysWithItsLetter() {
        #expect(MemberNameInitials.initials(for: "E\u{301}lodie Durand") == "E\u{301}.D")
    }
}

struct MemberNameLimitTests {
    @Test
    func theNameLimitIsTwentyUTF16Units() {
        #expect(SsoSignupNamePolicy.maxLength == 20)
        #expect(SsoSignupNamePolicy.fits("Christopher Johnson1"))
        #expect(!SsoSignupNamePolicy.fits("Christopher Johnson12"))
    }

    @Test
    func theAuxiliaryAccountModalUsesTheSharedNamePolicy() throws {
        let myInfo = try String(
            contentsOf: Self.projectRoot.appending(path: "Dutypark/Features/Settings/MyInfoView.swift"),
            encoding: .utf8
        )
        let start = try #require(myInfo.range(of: "private struct AuxiliaryAccountModal"))
        let end = myInfo.range(of: "\nprivate struct ", range: start.upperBound..<myInfo.endIndex)?.lowerBound
            ?? myInfo.endIndex
        let modal = myInfo[start.upperBound..<end]
        #expect(modal.contains("name = SsoSignupNamePolicy.truncated(value)"))
        #expect(modal.contains("SsoSignupNamePolicy.length(of: name)"))
        #expect(modal.contains("SsoSignupNamePolicy.maxLength"))
        #expect(!modal.contains("prefix("))
        #expect(!modal.contains("name.count"))
        #expect(!modal.contains("/10"))
    }

    /// Only the number changes: every name-length message now says 20.
    @Test(arguments: [
        ("OAuth", "auth.oauth.signup.name.help"),
        ("Errors", "sso.username.length"),
        ("Settings", "settings.auxiliary.description"),
        ("Settings", "settings.name.description"),
        ("Settings", "settings.name.invalid"),
    ])
    func nameLengthCopySaysTwenty(table: String, key: String) throws {
        for locale in ["en", "ko"] {
            let url = try #require(Bundle.main.url(forResource: locale, withExtension: "lproj"))
            let bundle = try #require(Bundle(url: url))
            let value = bundle.localizedString(forKey: key, value: key, table: table)
            #expect(value != key, "Missing \(key) for \(locale)")
            #expect(value.contains("20"), "\(key) \(locale): \(value)")
            #expect(!value.contains("10"), "\(key) \(locale): \(value)")
        }
    }

    private static var projectRoot: URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
    }
}

/// A month-cell tag counts characters like the web's `calendarTagLabel`: up to three
/// whole, then initials when the name has them, else two characters and "…".
struct MemberTagMicroLabelTests {
    @Test(arguments: [
        ("김하나", "김하나"),
        ("Ann", "Ann"),
        ("Al B", "A.B"),
        ("Shane Park", "S.P"),
        ("Mary Jane Lee", "M.J.L"),
        ("Christopher Johnson", "C.J"),
        ("Christopher", "Ch…"),
        ("남궁민수", "남궁…"),
        ("Shane 박", "Sh…"),
    ])
    func theMicroTagUsesInitialsOnlyPastItsCharacterLimit(name: String, label: String) {
        #expect(DPMemberTagPresentation.displayName(name, limit: DPMemberTagSize.micro.nameCharacterLimit) == label)
    }

    @Test
    func widerTagsKeepTheFullName() {
        for size in [DPMemberTagSize.compact, .regular] {
            #expect(DPMemberTagPresentation.displayName("Christopher Johnson", limit: size.nameCharacterLimit) == "Christopher Johnson")
        }
    }
}

/// A ribbon tries each chip count with full names first, then with initials, before it
/// gives up a chip.
struct CalendarSpanTagInitialsFitTests {
    @Test
    func initialsLevelsFollowEachFullNameLevelThatHasInitials() {
        let initials: [String?] = ["S.P", nil, "M.J.L"]
        #expect(DPCalendarSpanTagFit.levels(tagCount: 3, initials: initials).prefix(6) == [
            .chips(shown: 3, more: 0),
            .chips(shown: 3, more: 0, abbreviated: true),
            .chips(shown: 2, more: 1),
            .chips(shown: 2, more: 1, abbreviated: true),
            .chips(shown: 1, more: 2),
            .chips(shown: 1, more: 2, abbreviated: true),
        ])
    }

    @Test
    func namesWithoutInitialsAddNoLevels() {
        #expect(
            DPCalendarSpanTagFit.levels(tagCount: 2, initials: [nil, nil])
                == DPCalendarSpanTagFit.levels(tagCount: 2)
        )
        let lateInitials: [String?] = [nil, "S.P"]
        #expect(DPCalendarSpanTagFit.levels(tagCount: 2, initials: lateInitials).prefix(3) == [
            .chips(shown: 2, more: 0),
            .chips(shown: 2, more: 0, abbreviated: true),
            .chips(shown: 1, more: 1),
        ])
    }
}

/// The shared narrow-slot name: the full name when it fits, initials only when it does not.
@MainActor
struct FittedMemberNameTests {
    @Test
    func aNameThatFitsIsDrawnInFull() throws {
        let fitted = try png(DPFittedMemberName(name: "Shane Park"), width: 200)
        let full = try png(Text(verbatim: "Shane Park"), width: 200)
        #expect(fitted == full)
    }

    @Test
    func anOverflowingNameFallsBackToItsInitials() throws {
        let fitted = try png(DPFittedMemberName(name: "Christopher Johnson"), width: 44)
        let initials = try png(Text(verbatim: "C.J"), width: 44)
        let truncated = try png(Text(verbatim: "Christopher Johnson"), width: 44)
        #expect(fitted == initials)
        #expect(fitted != truncated)
    }

    @Test
    func anOverflowingNameWithoutInitialsKeepsItsTruncation() throws {
        let fitted = try png(DPFittedMemberName(name: "Christopherson"), width: 44)
        let truncated = try png(Text(verbatim: "Christopherson"), width: 44)
        #expect(fitted == truncated)
    }

    /// A card's stack places the name at exactly the width it measured; the name must not
    /// flip to its initials there.
    @Test(arguments: ["Shane Park", "Sarah Kim", "Steven Kang", "Ann Lee"])
    func aNameThatFitsStaysInFullInsideAStack(name: String) throws {
        let fitted = try png(VStack(spacing: 4) { DPFittedMemberName(name: name); Text(verbatim: "Dutypark") }, width: 120)
        let full = try png(VStack(spacing: 4) { Text(verbatim: name); Text(verbatim: "Dutypark") }, width: 120)
        #expect(fitted == full)
    }

    /// A slot that lets its name shrink counts a name that fits once shrunk as fitting.
    @Test
    func aNameThatFitsOnceShrunkIsDrawnInFull() throws {
        let ideal = UIHostingController(rootView: Text(verbatim: "Shane Park")
            .font(DPFont.bold(size: 12, relativeTo: .caption)))
            .sizeThatFits(in: CGSize(width: CGFloat.infinity, height: .infinity)).width
        let width = (ideal * 0.85).rounded(.up)
        let fitted = try png(DPFittedMemberName(name: "Shane Park").minimumScaleFactor(0.75), width: width)
        let shrunk = try png(Text(verbatim: "Shane Park").minimumScaleFactor(0.75), width: width)
        let initials = try png(Text(verbatim: "S.P"), width: width)
        #expect(fitted == shrunk)
        #expect(fitted != initials)
    }

    /// A slot sized to the name's ideal width still gets the full-size name, not a shrunk one.
    @Test
    func aShrinkableNameKeepsItsFullIdealWidth() throws {
        let fitted = try png(DPFittedMemberName(name: "Shane Park").minimumScaleFactor(0.75).fixedSize(), width: 200)
        let full = try png(Text(verbatim: "Shane Park").minimumScaleFactor(0.75).fixedSize(), width: 200)
        #expect(fitted == full)
    }

    @Test
    func aNameTooWideEvenShrunkFallsBackToItsInitials() throws {
        let fitted = try png(DPFittedMemberName(name: "Christopher Johnson").minimumScaleFactor(0.75), width: 44)
        let initials = try png(Text(verbatim: "C.J").minimumScaleFactor(0.75), width: 44)
        #expect(fitted == initials)
    }

    private func png(_ view: some View, width: CGFloat) throws -> Data {
        let renderer = ImageRenderer(content: view
            .font(DPFont.bold(size: 12, relativeTo: .caption))
            .lineLimit(1)
            .frame(width: width, height: 40))
        renderer.scale = 3
        return try #require(renderer.uiImage?.pngData())
    }
}
