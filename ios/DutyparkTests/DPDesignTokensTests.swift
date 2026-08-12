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

    @Test
    func typographyContractSnapshotMatchesWebScaleAndBundledFamily() {
        #expect(
            DPTypography.webScaleSnapshot ==
                "display:30/bold|pageTitle:24/bold|sectionTitle:20/bold|heading:18/semibold|body:16/regular|bodyMedium:16/medium|label:14/medium|supporting:14/regular|caption:12/regular|family:MaplestoryOTF"
        )
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
}
