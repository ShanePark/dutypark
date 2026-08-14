import SwiftUI
import UIKit

/// Semantic colors mirrored from `frontend/src/style.css`.
///
/// Screens should use these names instead of system colors so light and dark
/// mode stay aligned with the web/PWA theme.
/// Color values are resolved by SwiftUI's asynchronous renderer as well as the
/// main actor. Keep this namespace nonisolated so UIKit's dynamic color
/// provider never inherits the app target's default MainActor isolation.
nonisolated enum DPColor {
    // MARK: Surfaces

    static let backgroundPrimary = adaptive(light: 0xFFFFFF, dark: 0x111827)
    static let backgroundSecondary = adaptive(light: 0xF9FAFB, dark: 0x1F2937)
    static let backgroundTertiary = adaptive(light: 0xF3F4F6, dark: 0x374151)
    static let backgroundHover = adaptive(light: 0xE5E7EB, dark: 0x4B5563)
    static let backgroundCard = adaptive(light: 0xFFFFFF, dark: 0x1F2937)
    static let backgroundInput = adaptive(light: 0xFFFFFF, dark: 0x374151)
    static let backgroundModal = adaptive(light: 0xFFFFFF, dark: 0x1F2937)
    static let backgroundFooter = adaptive(light: 0x1F2937, dark: 0x030712)

    // MARK: Text

    static let textPrimary = adaptive(light: 0x111827, dark: 0xF9FAFB)
    static let textSecondary = adaptive(light: 0x4B5563, dark: 0xD1D5DB)
    static let textMuted = adaptive(light: 0x6B7280, dark: 0x9CA3AF)
    static let textOnDark = fixed(0xFFFFFF)
    static let textOnDarkMuted = fixed(0xFFFFFF, opacity: 0.70)
    static let textOnLight = fixed(0x1F2937)

    // MARK: Borders

    static let borderPrimary = adaptive(light: 0xE5E7EB, dark: 0x374151)
    static let borderSecondary = adaptive(light: 0xD1D5DB, dark: 0x4B5563)
    static let borderInput = adaptive(light: 0xD1D5DB, dark: 0x4B5563)

    // MARK: Actions and statuses

    static let accent = fixed(0x3B82F6)
    static let accentHover = fixed(0x2563EB)
    static let accentSoft = adaptive(light: 0xEFF6FF, dark: 0x1E3A5F)
    static let accentSoftHover = adaptive(light: 0xDBEAFE, dark: 0x1E40AF)
    static let accentBorder = adaptive(light: 0x93C5FD, dark: 0x3B82F6)

    static let success = fixed(0x22C55E)
    static let successHover = fixed(0x16A34A)
    static let successSoft = adaptive(light: 0xF0FDF4, dark: 0x14532D)
    static let successBorder = adaptive(light: 0x86EFAC, dark: 0x22C55E)

    static let warning = fixed(0xF59E0B)
    static let warningHover = fixed(0xD97706)
    static let warningSoft = adaptive(light: 0xFFFBEB, dark: 0x451A03)
    static let warningSoftHover = adaptive(light: 0xFEF3C7, dark: 0x78350F)
    static let warningBorder = adaptive(light: 0xFCD34D, dark: 0xF59E0B)

    static let danger = fixed(0xEF4444)
    static let dangerHover = fixed(0xDC2626)
    static let dangerSoft = adaptive(light: 0xFEF2F2, dark: 0x450A0A)
    static let dangerSoftHover = adaptive(light: 0xFEE2E2, dark: 0x7F1D1D)
    static let dangerBorder = adaptive(light: 0xFECACA, dark: 0xEF4444)

    static let surfaceStrong = adaptive(light: 0x4B5563, dark: 0x374151)
    static let surfaceStrongAlt = adaptive(light: 0x6B7280, dark: 0x4B5563)

    private static func fixed(_ hex: UInt32, opacity: CGFloat = 1) -> Color {
        Color(uiColor: UIColor(hex: hex, alpha: opacity))
    }

    private static func adaptive(light: UInt32, dark: UInt32) -> Color {
        Color(
            uiColor: UIColor { traits in
                UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
            }
        )
    }
}

/// Four-point spacing scale corresponding to the Tailwind spacing used by the web UI.
enum DPSpacing {
    static let extraSmall: CGFloat = 4  // `1`
    static let small: CGFloat = 8       // `2`
    static let compact: CGFloat = 12    // `3`
    static let medium: CGFloat = 16     // `4`
    static let large: CGFloat = 24      // `6`
    static let extraLarge: CGFloat = 32 // `8`
}

enum DPRadius {
    static let small: CGFloat = 4       // `rounded`
    static let compact: CGFloat = 6     // `rounded-md`
    static let standard: CGFloat = 8    // `rounded-lg`: cards, buttons and inputs
    static let large: CGFloat = 12      // `rounded-xl`
    static let extraLarge: CGFloat = 16 // `rounded-2xl`
}

enum DPSize {
    /// Minimum interactive target size used throughout the mobile UI.
    static let minimumTouchTarget: CGFloat = 44
    static let iconSmall: CGFloat = 16
    static let icon: CGFloat = 20
    static let iconLarge: CGFloat = 24
}

/// Web type scale rendered with Nexon's original MapleStory OTF assets.
enum DPTypography {
    static let display = DPFont.bold(size: 30, relativeTo: .largeTitle)
    static let pageTitle = DPFont.bold(size: 24, relativeTo: .title2)
    static let sectionTitle = DPFont.bold(size: 20, relativeTo: .title3)
    static let heading = DPFont.bold(size: 18, relativeTo: .headline)
    static let body = DPFont.light(size: 16, relativeTo: .body)
    static let bodyMedium = DPFont.light(size: 16, relativeTo: .body)
    static let label = DPFont.light(size: 14, relativeTo: .subheadline)
    static let supporting = DPFont.light(size: 14, relativeTo: .subheadline)
    static let caption = DPFont.light(size: 12, relativeTo: .caption)

    /// Stable metadata used by contract tests and visual regression tooling.
    static let webScaleSnapshot = "display:30/bold|pageTitle:24/bold|sectionTitle:20/bold|heading:18/semibold|body:16/regular|bodyMedium:16/medium|label:14/medium|supporting:14/regular|caption:12/regular|family:MaplestoryOTF"
}

enum DPChrome {
    static let borderWidth: CGFloat = 1
    static let focusRingWidth: CGFloat = 2
    static let controlHorizontalPadding: CGFloat = 16
    static let inputHorizontalPadding: CGFloat = 12
    static let inputVerticalPadding: CGFloat = 8
    static let disabledOpacity: Double = 0.5

    static func shadowOpacity(for colorScheme: ColorScheme) -> Double {
        colorScheme == .dark ? 0.30 : 0.05
    }
}

private extension UIColor {
    nonisolated convenience init(hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}
