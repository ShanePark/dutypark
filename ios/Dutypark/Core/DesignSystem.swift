import SwiftUI

// MARK: - Dutypark Design System
// Based on frontend/src/style.css design tokens

// MARK: - Color Theme
enum DPColorScheme {
    case light
    case dark
}

// MARK: - Design Tokens
struct DesignSystem {

    // MARK: - Colors
    struct Colors {
        // Background Colors
        static let bgPrimary = Color("BGPrimary")
        static let bgSecondary = Color("BGSecondary")
        static let bgTertiary = Color("BGTertiary")
        static let bgCard = Color("BGCard")
        static let bgFooter = Color("BGFooter")

        // Text Colors
        static let textPrimary = Color("TextPrimary")
        static let textSecondary = Color("TextSecondary")
        static let textMuted = Color("TextMuted")

        // Border Colors
        static let borderPrimary = Color("BorderPrimary")
        static let borderSecondary = Color("BorderSecondary")

        // Accent Colors
        static let accent = Color.blue
        static let accentLight = Color.blue.opacity(0.6)

        // Semantic Colors
        static let success = Color.green
        static let danger = Color.red
        static let warning = Color.orange

        // Calendar Colors
        static let sunday = Color.red
        static let saturday = Color.blue

        // Kakao OAuth
        static let kakao = Color(hex: "#FEE500")!
        static let kakaoText = Color.black

        // Friend Card Section Header
        static let friendRequestHeader = Color.orange
        static let friendListHeader = Color(hex: "#374151")!

        // Light mode colors (for manual usage)
        struct Light {
            static let bgPrimary = Color.white
            static let bgSecondary = Color(hex: "#F9FAFB")!
            static let bgTertiary = Color(hex: "#F3F4F6")!
            static let bgCard = Color.white
            static let bgFooter = Color(hex: "#1F2937")!

            static let textPrimary = Color(hex: "#111827")!
            static let textSecondary = Color(hex: "#4B5563")!
            static let textMuted = Color(hex: "#6B7280")!

            static let borderPrimary = Color(hex: "#E5E7EB")!
            static let borderSecondary = Color(hex: "#D1D5DB")!
        }

        // Dark mode colors (for manual usage)
        struct Dark {
            static let bgPrimary = Color(hex: "#111827")!
            static let bgSecondary = Color(hex: "#1F2937")!
            static let bgTertiary = Color(hex: "#374151")!
            static let bgCard = Color(hex: "#1F2937")!
            static let bgFooter = Color(hex: "#030712")!

            static let textPrimary = Color(hex: "#F9FAFB")!
            static let textSecondary = Color(hex: "#D1D5DB")!
            static let textMuted = Color(hex: "#9CA3AF")!

            static let borderPrimary = Color(hex: "#374151")!
            static let borderSecondary = Color(hex: "#4B5563")!
        }
    }

    // MARK: - Typography
    struct Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.semibold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline
        static let body = Font.body
        static let callout = Font.callout
        static let subheadline = Font.subheadline
        static let footnote = Font.footnote
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }

    // MARK: - Spacing
    struct Spacing {
        static let xxs: CGFloat = 2
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
    }

    // MARK: - Corner Radius
    struct CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let full: CGFloat = 9999
    }

    // MARK: - Shadow
    struct Shadow {
        static func sm(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.black.opacity(0.3)
                : Color.black.opacity(0.05)
        }

        static func md(_ colorScheme: ColorScheme) -> Color {
            colorScheme == .dark
                ? Color.black.opacity(0.4)
                : Color.black.opacity(0.1)
        }
    }
}


// MARK: - View Modifiers

/// Card style modifier matching web's .card class
struct CardStyle: ViewModifier {
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        content
            .background(colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard)
            .cornerRadius(DesignSystem.CornerRadius.lg)
            .shadow(color: DesignSystem.Shadow.sm(colorScheme), radius: 4, x: 0, y: 2)
    }
}

/// Section header style matching web's friend section headers
struct SectionHeaderStyle: ViewModifier {
    let backgroundColor: Color

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignSystem.Spacing.lg)
            .padding(.vertical, DesignSystem.Spacing.md)
            .background(backgroundColor)
            .cornerRadius(DesignSystem.CornerRadius.sm)
    }
}

extension View {
    func cardStyle() -> some View {
        modifier(CardStyle())
    }

    func sectionHeader(backgroundColor: Color) -> some View {
        modifier(SectionHeaderStyle(backgroundColor: backgroundColor))
    }
}

// MARK: - Adaptive Colors (responds to system color scheme)
struct AdaptiveColor {
    @Environment(\.colorScheme) var colorScheme

    var bgPrimary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.bgPrimary : DesignSystem.Colors.Light.bgPrimary
    }

    var bgSecondary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.bgSecondary : DesignSystem.Colors.Light.bgSecondary
    }

    var bgTertiary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.bgTertiary : DesignSystem.Colors.Light.bgTertiary
    }

    var bgCard: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.bgCard : DesignSystem.Colors.Light.bgCard
    }

    var textPrimary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textPrimary : DesignSystem.Colors.Light.textPrimary
    }

    var textSecondary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textSecondary : DesignSystem.Colors.Light.textSecondary
    }

    var textMuted: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.textMuted : DesignSystem.Colors.Light.textMuted
    }

    var borderPrimary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.borderPrimary : DesignSystem.Colors.Light.borderPrimary
    }

    var borderSecondary: Color {
        colorScheme == .dark ? DesignSystem.Colors.Dark.borderSecondary : DesignSystem.Colors.Light.borderSecondary
    }
}

// MARK: - Environment Key for Adaptive Colors
struct AdaptiveColorKey: EnvironmentKey {
    static let defaultValue = AdaptiveColor()
}

extension EnvironmentValues {
    var adaptiveColors: AdaptiveColor {
        get { self[AdaptiveColorKey.self] }
        set { self[AdaptiveColorKey.self] = newValue }
    }
}

// MARK: - D-Day Badge Styles
enum DDayBadgeStyle {
    case today
    case past
    case upcoming1 // D-1 to D-7
    case upcoming2 // D-8 to D-14
    case upcoming3 // D-15 to D-30
    case future    // D-30+

    var backgroundColor: Color {
        switch self {
        case .today:
            return Color.red
        case .past:
            return Color.gray
        case .upcoming1:
            return Color.red
        case .upcoming2:
            return Color.orange
        case .upcoming3:
            return Color(hex: "#FB923C")!
        case .future:
            return Color(hex: "#374151")!
        }
    }

    var textColor: Color {
        switch self {
        case .today, .past, .upcoming1, .upcoming2, .upcoming3:
            return .white
        case .future:
            return Color(hex: "#F9FAFB")!
        }
    }

    static func style(for daysRemaining: Int) -> DDayBadgeStyle {
        if daysRemaining == 0 {
            return .today
        } else if daysRemaining < 0 {
            return .past
        } else if daysRemaining <= 7 {
            return .upcoming1
        } else if daysRemaining <= 14 {
            return .upcoming2
        } else if daysRemaining <= 30 {
            return .upcoming3
        } else {
            return .future
        }
    }
}

// MARK: - Todo Status Colors Extension
extension TodoStatus {
    var backgroundColor: Color {
        switch self {
        case .todo:
            return Color.blue.opacity(0.15)
        case .inProgress:
            return Color.orange.opacity(0.15)
        case .done:
            return Color.green.opacity(0.15)
        }
    }

    var foregroundColor: Color {
        switch self {
        case .todo:
            return Color.blue
        case .inProgress:
            return Color.orange
        case .done:
            return Color.green
        }
    }
}

