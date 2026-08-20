import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
struct DPDesignTokensTests {
    @Test
    func surfaceAndTextColorsMatchWebTheme() {
        #expect(rgb(of: DPColor.backgroundPrimary, style: .light) == (255, 255, 255))
        #expect(rgb(of: DPColor.backgroundPrimary, style: .dark) == (17, 24, 39))
        #expect(rgb(of: DPColor.backgroundInput, style: .dark) == (55, 65, 81))
        #expect(rgb(of: DPColor.textPrimary, style: .light) == (17, 24, 39))
        #expect(rgb(of: DPColor.textSecondary, style: .dark) == (209, 213, 219))
    }

    @Test
    func semanticActionPalettesMatchWebTheme() {
        #expect(rgb(of: DPColor.accent, style: .light) == (59, 130, 246))
        #expect(rgb(of: DPColor.accentHover, style: .dark) == (37, 99, 235))
        #expect(rgb(of: DPColor.successSoft, style: .light) == (240, 253, 244))
        #expect(rgb(of: DPColor.warningSoft, style: .dark) == (69, 26, 3))
        #expect(rgb(of: DPColor.dangerSoftHover, style: .dark) == (127, 29, 29))
    }

    @Test
    func layoutAndChromeMatchWebComponents() {
        #expect(DPRadius.standard == 8)
        #expect(DPSpacing.compact == 12)
        #expect(DPSpacing.medium == 16)
        #expect(DPSize.minimumTouchTarget == 44)
        #expect(DPChrome.borderWidth == 1)
        #expect(DPChrome.controlHorizontalPadding == 16)
        #expect(DPChrome.inputHorizontalPadding == 12)
        #expect(DPChrome.inputVerticalPadding == 8)
        #expect(DPChrome.disabledOpacity == 0.5)
        #expect(DPChrome.shadowOpacity(for: .light) == 0.05)
        #expect(DPChrome.shadowOpacity(for: .dark) == 0.30)
    }

    /// The frosted backdrop is laid down part-way on purpose. At full strength the
    /// thinnest system material still blanks out everything behind a modal, which
    /// reads as a broken screen rather than as focus.
    @Test
    func theModalBackdropLeavesTheScreenBehindVisible() {
        #expect(DPChrome.overlayMaterialOpacity == 0.45)
    }

    @Test
    func typographyContractSnapshotMatchesWebScaleAndBundledFamily() {
        #expect(
            DPTypography.webScaleSnapshot ==
                "display:30/bold|pageTitle:24/bold|sectionTitle:20/bold|heading:18/semibold|body:16/regular|bodyMedium:16/medium|label:14/medium|supporting:14/regular|caption:12/regular|family:MaplestoryOTF"
        )
    }

    @Test
    func increaseContrastDarkensLowContrastTokens() {
        #expect(rgb(of: DPColor.textSecondary, style: .light, contrast: .high) == (31, 41, 55))
        #expect(rgb(of: DPColor.textSecondary, style: .dark, contrast: .high) == (249, 250, 251))
        #expect(rgb(of: DPColor.textMuted, style: .light, contrast: .high) == (55, 65, 81))
        #expect(rgb(of: DPColor.textMuted, style: .dark, contrast: .high) == (209, 213, 219))
        #expect(rgb(of: DPColor.borderPrimary, style: .light, contrast: .high) == (107, 114, 128))
        #expect(rgb(of: DPColor.borderPrimary, style: .dark, contrast: .high) == (156, 163, 175))
        #expect(rgb(of: DPColor.borderSecondary, style: .light, contrast: .high) == (75, 85, 99))
        #expect(rgb(of: DPColor.borderSecondary, style: .dark, contrast: .high) == (156, 163, 175))
        #expect(rgb(of: DPColor.borderInput, style: .light, contrast: .high) == (75, 85, 99))
        #expect(rgb(of: DPColor.borderInput, style: .dark, contrast: .high) == (209, 213, 219))
    }

    @Test
    func normalContrastKeepsTheWebThemeValues() {
        #expect(rgb(of: DPColor.textMuted, style: .light, contrast: .normal) == (107, 114, 128))
        #expect(rgb(of: DPColor.textMuted, style: .dark, contrast: .normal) == (156, 163, 175))
        #expect(rgb(of: DPColor.borderInput, style: .light, contrast: .normal) == (209, 213, 219))
    }

    @Test
    func tokensWithoutAHighContrastVariantStayOnTheWebValue() {
        #expect(rgb(of: DPColor.backgroundPrimary, style: .light, contrast: .high) == (255, 255, 255))
        #expect(rgb(of: DPColor.backgroundPrimary, style: .dark, contrast: .high) == (17, 24, 39))
        #expect(rgb(of: DPColor.textPrimary, style: .light, contrast: .high) == (17, 24, 39))
        #expect(rgb(of: DPColor.textPrimary, style: .dark, contrast: .high) == (249, 250, 251))
    }

    @Test
    func highContrastTextTokensClearTheEnhancedContrastThreshold() {
        for style in [UIUserInterfaceStyle.light, .dark] {
            for token in [("textSecondary", DPColor.textSecondary), ("textMuted", DPColor.textMuted)] {
                let ratio = contrastRatio(
                    token.1,
                    on: DPColor.backgroundPrimary,
                    style: style,
                    contrast: .high
                )
                #expect(ratio >= 7, "\(token.0) on style \(style.rawValue) was \(ratio):1")
            }
        }
    }

    @Test
    nonisolated func adaptiveColorsResolveAwayFromMainActor() async {
        let resolved = await Task.detached {
            rgb(of: DPColor.backgroundCard, style: .dark)
        }.value

        #expect(resolved == (31, 41, 55))
    }

    private nonisolated func rgb(
        of color: Color,
        style: UIUserInterfaceStyle
    ) -> (Int, Int, Int) {
        let resolved = UIColor(color).resolvedColor(
            with: UITraitCollection(userInterfaceStyle: style)
        )
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private nonisolated func rgb(
        of color: Color,
        style: UIUserInterfaceStyle,
        contrast: UIAccessibilityContrast
    ) -> (Int, Int, Int) {
        let resolved = UIColor(color).resolvedColor(with: traits(style: style, contrast: contrast))
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        resolved.getRed(&red, green: &green, blue: &blue, alpha: nil)
        return (
            Int((red * 255).rounded()),
            Int((green * 255).rounded()),
            Int((blue * 255).rounded())
        )
    }

    private nonisolated func traits(
        style: UIUserInterfaceStyle,
        contrast: UIAccessibilityContrast
    ) -> UITraitCollection {
        UITraitCollection(userInterfaceStyle: style).modifyingTraits { mutable in
            mutable.accessibilityContrast = contrast
        }
    }

    /// WCAG relative-luminance contrast ratio, so the accessibility expectations
    /// are stated as a threshold instead of a hard-coded pair of hex values.
    private nonisolated func contrastRatio(
        _ foreground: Color,
        on background: Color,
        style: UIUserInterfaceStyle,
        contrast: UIAccessibilityContrast
    ) -> Double {
        let traitCollection = traits(style: style, contrast: contrast)
        let first = luminance(of: UIColor(foreground).resolvedColor(with: traitCollection))
        let second = luminance(of: UIColor(background).resolvedColor(with: traitCollection))
        let lighter = max(first, second)
        let darker = min(first, second)
        return (lighter + 0.05) / (darker + 0.05)
    }

    private nonisolated func luminance(of color: UIColor) -> Double {
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        color.getRed(&red, green: &green, blue: &blue, alpha: nil)
        func linear(_ channel: CGFloat) -> Double {
            let value = Double(channel)
            return value <= 0.03928 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
    }
}
