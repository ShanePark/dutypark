import SwiftUI
import Testing
import UIKit
@testable import Dutypark

/// Member tags share the web's "A" surface: a faint top-lit gradient, a hairline top
/// highlight and a hard, unblurred hint of a shadow.
struct MemberTagGlossTests {
    /// On a duty fill the chip stays the fixed white glass the web draws there; the gradient
    /// only redistributes the old flat 0.72 white between its top and bottom.
    @Test
    func onACalendarFillTheGradientIsFixedWhiteAveragingTheOldFlatFill() {
        let fill = DPMemberTagPalette.gradient(onCalendarFill: true)
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(matches(fill.top, style, [255, 255, 255], 0.84), "0.84 white")
            #expect(matches(fill.bottom, style, [255, 255, 255], 0.62), "0.62 white")
            #expect(matches(DPMemberTagPalette.highlight(onCalendarFill: true), style, [255, 255, 255], 0.95), "0.95 white")
        }
        #expect(abs((0.84 + 0.62) / 2 - 0.72) < 0.011)
        // The fixed border and ink of the fill contract are untouched.
        #expect(matches(DPMemberTagPalette.border(onCalendarFill: true), .light, [31, 41, 55], 0.14))
        #expect(matches(DPMemberTagPalette.foreground(onCalendarFill: true), .light, [55, 65, 81], 1))
    }

    /// Off a fill the chip follows the theme: `--dp-bg-card` darkened 5% toward slate at the
    /// bottom in light, lightened 12% toward white at the top in dark.
    @Test
    func offAFillTheGradientIsTheThemeCardLitFromAbove() {
        let theme = DPMemberTagPalette.gradient(onCalendarFill: false)
        #expect(matches(theme.top, .light, [255, 255, 255], 1))
        #expect(matches(theme.bottom, .light, [243, 243, 244], 1))
        #expect(matches(theme.top, .dark, [58, 67, 79], 1))
        #expect(matches(theme.bottom, .dark, [31, 41, 55], 1))

        let highlight = DPMemberTagPalette.highlight(onCalendarFill: false)
        #expect(matches(highlight, .light, [255, 255, 255], 0.95))
        #expect(matches(highlight, .dark, [255, 255, 255], 0.10))
    }

    /// The shadow is a capsule nudged below the chip, never a blur. It is left off where it
    /// would show through a translucent chip or crowd a month cell.
    @Test
    func onlyOpaqueListAndDetailChipsCastTheHardShadow() {
        #expect(DPMemberTagPalette.castsShadow(size: .regular, onCalendarFill: false))
        #expect(DPMemberTagPalette.castsShadow(size: .compact, onCalendarFill: false))
        #expect(!DPMemberTagPalette.castsShadow(size: .micro, onCalendarFill: false))
        for size in [DPMemberTagSize.micro, .compact, .regular] {
            #expect(!DPMemberTagPalette.castsShadow(size: size, onCalendarFill: true))
        }
        #expect(DPMemberTagPalette.shadowOffset > 0.5, "Peeks out past the 1pt border's outer half")
        #expect(matches(DPMemberTagPalette.shadow, .light, [15, 23, 42], 0.10))
        #expect(matches(DPMemberTagPalette.shadow, .dark, [0, 0, 0], 0.35))
    }

    /// Ribbon tags keep their ink tint and gain the web's mini sheen on top.
    @Test
    func ribbonTagsGainTheMiniSheen() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            #expect(matches(DPCalendarSpanTagSheen.top, style, [255, 255, 255], 0.30))
            #expect(matches(DPCalendarSpanTagSheen.highlight, style, [255, 255, 255], 0.70))
        }
        #expect(DPCalendarSpanTagSheen.fadeEnd == 0.85)
    }

    /// Many chips are drawn per month, so none of them may blur or sample what is behind.
    @Test
    func noTagChipBlursOrUsesAMaterial() throws {
        let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        let chip = try String(contentsOf: root.appending(path: "Dutypark/Components/DPMemberTagChip.swift"), encoding: .utf8)
        let ribbon = try String(contentsOf: root.appending(path: "Dutypark/Components/DPCalendarSpanRibbon.swift"), encoding: .utf8)
        let selector = try String(contentsOf: root.appending(path: "Dutypark/Components/DPFriendTagSelector.swift"), encoding: .utf8)
        // The band itself keeps its one shadow; only its tags are checked.
        let cluster = try #require(ribbon.range(of: "private struct DPCalendarSpanTagCluster"))
        let ribbonTags = String(ribbon[cluster.lowerBound...])
        for (name, source) in [("chip", chip), ("ribbon tags", ribbonTags), ("selector", selector)] {
            #expect(!source.contains(".shadow("), "\(name)")
            #expect(!source.contains("glassEffect"), "\(name)")
            #expect(!source.contains(".blur("), "\(name)")
        }
        #expect(!chip.contains("Material"))
        #expect(!chip.contains("drawingGroup"))
        #expect(chip.contains("DPMemberTagSurface("))
        #expect(ribbonTags.components(separatedBy: "sheen(").count - 1 >= 4, "Chip, pill and compact pill wear the sheen")
        #expect(selector.contains("DPMemberTagSurface("), "The picker's selected tags match the tags they become")
    }

    /// The surface sits behind the content, so a chip is exactly as large as before.
    @MainActor
    @Test
    func theSurfaceDoesNotChangeAChipsSize() throws {
        let item = DPMemberTagItem(memberID: 1, name: "김하나")
        for size in [DPMemberTagSize.micro, .compact, .regular] {
            for onFill in [false, true] {
                let chip = ImageRenderer(content: DPMemberTagChip(item: item, size: size, onCalendarFill: onFill).fixedSize())
                let bare = ImageRenderer(content: HStack(spacing: size.spacing) {
                    DPMemberAvatar(item: item, diameter: size.avatarDiameter)
                    Text(DPMemberTagPresentation.displayName(item.name, limit: size.nameCharacterLimit))
                        .font(DPFont.light(size: size.fontSize, relativeTo: size.relativeTextStyle))
                        .lineLimit(1)
                }
                .padding(.leading, size.verticalPadding)
                .padding(.trailing, size.horizontalPadding)
                .padding(.vertical, size.verticalPadding)
                .fixedSize())
                #expect(try #require(chip.uiImage).size == (try #require(bare.uiImage)).size, "\(size) onFill=\(onFill)")
            }
        }
    }

    private func matches(_ color: Color, _ style: UIUserInterfaceStyle, _ rgb: [Int], _ alpha: Double) -> Bool {
        let resolved = UIColor(color).resolvedColor(with: UITraitCollection(userInterfaceStyle: style))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, actualAlpha: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: &actualAlpha)
        return [red, green, blue].map { Int(($0 * 255).rounded()) } == rgb && abs(Double(actualAlpha) - alpha) < 0.005
    }
}
