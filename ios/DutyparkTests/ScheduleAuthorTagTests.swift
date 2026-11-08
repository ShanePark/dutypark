import SwiftUI
import UIKit
import XCTest
@testable import Dutypark

@MainActor
final class ScheduleAuthorTagTests: XCTestCase {
    func testOnlyAuthorTagsExposeTheLocalizedRole() {
        let ordinary = DPMemberTagItem(memberID: 2, name: "하나")
        let author = DPMemberTagItem(memberID: 2, name: "하나", isAuthor: true)
        XCTAssertFalse(ordinary.isAuthor)
        XCTAssertEqual(DPMemberTagPresentation.accessibilityLabel(for: ordinary), "하나")
        XCTAssertEqual(DPMemberTagPresentation.accessibilityLabel(for: author, locale: Locale(identifier: "ko")), "하나, 작성자")
        XCTAssertEqual(DPMemberTagPresentation.accessibilityLabel(for: author, locale: Locale(identifier: "en")), "하나, author")
    }

    func testOnlyDetailAuthorTagsChangeTheirBorderWithoutTakingNameSpace() throws {
        let ordinary = DPMemberTagItem(memberID: 1, name: "김하나")
        let author = DPMemberTagItem(memberID: 1, name: "김하나", isAuthor: true)
        for theme in [ColorScheme.light, .dark] {
            for size in [DPMemberTagSize.micro, .compact, .regular] {
                for onFill in [false, true] {
                    let plain = ImageRenderer(content: DPMemberTagChip(item: ordinary, size: size, onCalendarFill: onFill)
                        .fixedSize().padding(4).environment(\.colorScheme, theme))
                    let marked = ImageRenderer(content: DPMemberTagChip(item: author, size: size, onCalendarFill: onFill)
                        .fixedSize().padding(4).environment(\.colorScheme, theme))
                    let plainImage = try XCTUnwrap(plain.uiImage)
                    let markedImage = try XCTUnwrap(marked.uiImage)
                    XCTAssertEqual(markedImage.size, plainImage.size)
                    if size == .regular {
                        XCTAssertNotEqual(markedImage.pngData(), plainImage.pngData(), "The detail author must have a distinct border")
                    } else {
                        XCTAssertEqual(markedImage.pngData(), plainImage.pngData(), "Month and list tags keep the original appearance")
                    }
                }
            }
            let preview = VStack(alignment: .leading, spacing: 12) {
                HStack {
                    DPMemberTagChip(item: author, size: .regular)
                    DPMemberTagChip(item: ordinary, size: .regular)
                }
                HStack {
                    DPMemberTagChip(item: author, size: .micro)
                    DPMemberTagChip(item: ordinary, size: .micro)
                }
            }
            .padding(12)
            .background(DPColor.backgroundCard)
            .environment(\.colorScheme, theme)
            let renderer = ImageRenderer(content: preview)
            renderer.scale = 3
            let attachment = XCTAttachment(image: try XCTUnwrap(renderer.uiImage))
            attachment.name = "author-border-\(theme)"
            attachment.lifetime = .keepAlways
            add(attachment)
        }
    }

    func testDetailAuthorBorderMatchesTheSharedColorMixInBothThemes() {
        let border = UIColor(DPMemberTagPalette.border(onCalendarFill: false, isAuthor: true))
        for (style, expected) in [(UIUserInterfaceStyle.light, [125.4, 163.4, 206.8]), (.dark, [104, 154.9, 237.9])] {
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0
            border.resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
                .getRed(&red, green: &green, blue: &blue, alpha: nil)
            for (actual, target) in zip([red, green, blue], expected) {
                XCTAssertEqual(Double(actual), target / 255, accuracy: 1 / 255)
            }
        }
    }

    func testAuthorRoleKeepsTheOriginalWrappedMonthTagSpacing() throws {
        let ordinary = DPMemberTagItem(memberID: 1, name: "김하나")
        let author = DPMemberTagItem(memberID: 1, name: "김하나", isAuthor: true)
        let participant = DPMemberTagItem(memberID: 2, name: "이두리")
        let plain = ImageRenderer(content: DPMemberTagChips(items: [ordinary, participant], size: .micro)
            .frame(width: 47).fixedSize().padding(4))
        let marked = ImageRenderer(content: DPMemberTagChips(items: [author, participant], size: .micro)
            .frame(width: 47).fixedSize().padding(4))
        let plainImage = try XCTUnwrap(plain.uiImage)
        let markedImage = try XCTUnwrap(marked.uiImage)
        XCTAssertEqual(markedImage.size, plainImage.size)
        XCTAssertEqual(markedImage.pngData(), plainImage.pngData())
    }
}
