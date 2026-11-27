import Foundation
import SwiftUI

/// The month tile's time chip takes its colours from the tile's own fill, in OKLCH, as the
/// web does with `oklch(from F …)`:
/// background `oklch(from F calc(l - 0.08) calc(c * 1.25) h)`,
/// text `oklch(from F 0.36 calc(c * 1.4) h)`, both clamped to sRGB.
/// A tile without a fill, or one where that pair would read below 4.5:1, uses the neutral chip.
nonisolated enum DPCalendarTimeChipPalette {
    struct RGB: Equatable {
        let red: Double
        let green: Double
        let blue: Double

        var hex: String {
            String(format: "#%02X%02X%02X", channel(red), channel(green), channel(blue))
        }

        var color: Color {
            Color(.sRGB, red: red, green: green, blue: blue)
        }

        private func channel(_ value: Double) -> Int {
            Int((min(max(value, 0), 1) * 255).rounded())
        }
    }

    struct Colors: Equatable {
        let background: RGB
        let foreground: RGB
    }

    static let minimumContrast = 4.5

    static func toneOnTone(fillHex: String?) -> Colors? {
        guard let fill = DPCalendarCellStyle.rgb(fillHex) else { return nil }
        let lab = oklab(RGB(red: Double(fill.red) / 255, green: Double(fill.green) / 255, blue: Double(fill.blue) / 255))
        let chroma = (lab.a * lab.a + lab.b * lab.b).squareRoot()
        let hue = atan2(lab.b, lab.a)
        func lch(_ lightness: Double, _ chroma: Double) -> RGB {
            srgb(lightness: lightness, a: chroma * cos(hue), b: chroma * sin(hue))
        }
        let colors = Colors(
            background: lch(lab.lightness - 0.08, chroma * 1.25),
            foreground: lch(0.36, chroma * 1.4)
        )
        return contrastRatio(colors.foreground, colors.background) >= minimumContrast ? colors : nil
    }

    static func contrastRatio(_ first: RGB, _ second: RGB) -> Double {
        let lighter = max(luminance(first), luminance(second))
        let darker = min(luminance(first), luminance(second))
        return (lighter + 0.05) / (darker + 0.05)
    }

    private static func luminance(_ color: RGB) -> Double {
        0.2126 * linear(color.red) + 0.7152 * linear(color.green) + 0.0722 * linear(color.blue)
    }

    private static func linear(_ value: Double) -> Double {
        value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4)
    }

    private static func gamma(_ value: Double) -> Double {
        let value = min(max(value, 0), 1)
        return value <= 0.0031308 ? value * 12.92 : 1.055 * pow(value, 1 / 2.4) - 0.055
    }

    private static func oklab(_ color: RGB) -> (lightness: Double, a: Double, b: Double) {
        let r = linear(color.red), g = linear(color.green), b = linear(color.blue)
        let l = cbrt(0.4122214708 * r + 0.5363325363 * g + 0.0514459929 * b)
        let m = cbrt(0.2119034982 * r + 0.6806995451 * g + 0.1073969566 * b)
        let s = cbrt(0.0883024619 * r + 0.2817188376 * g + 0.6299787005 * b)
        return (
            0.2104542553 * l + 0.7936177850 * m - 0.0040720468 * s,
            1.9779984951 * l - 2.4285922050 * m + 0.4505937099 * s,
            0.0259040371 * l + 0.7827717662 * m - 0.8086757660 * s
        )
    }

    private static func srgb(lightness: Double, a: Double, b: Double) -> RGB {
        func cube(_ value: Double) -> Double { value * value * value }
        let l = cube(lightness + 0.3963377774 * a + 0.2158037573 * b)
        let m = cube(lightness - 0.1055613458 * a - 0.0638541728 * b)
        let s = cube(lightness - 0.0894841775 * a - 1.2914855480 * b)
        return RGB(
            red: gamma(4.0767416621 * l - 3.3077115913 * m + 0.2309699292 * s),
            green: gamma(-1.2684380046 * l + 2.6097574011 * m - 0.3413193965 * s),
            blue: gamma(-0.0041960863 * l - 0.7034186147 * m + 1.7076147010 * s)
        )
    }
}

extension DPCalendarCellStyle {
    /// The time chip on a tile: tone-on-tone on a duty fill, otherwise the tile's ink at
    /// 8.5% behind the ink at 82%.
    static func timeChipColors(dutyColor: String?, isCurrentMonth: Bool) -> (background: Color, foreground: Color) {
        if let chip = DPCalendarTimeChipPalette.toneOnTone(
            fillHex: fillHex(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        ) {
            return (chip.background.color, chip.foreground.color)
        }
        let ink = primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        return (ink.opacity(0.085), ink.opacity(0.82))
    }
}

/// A schedule's time in a month tile: a chip on its own line under the title, so the
/// title's two-line limit can never clip it. A range wraps only after its "~".
struct DPCalendarScheduleTime: View {
    static let tracking: CGFloat = -0.36
    /// 0.77em of the tile's item text, so a full range fits one line in a 375pt-wide tile.
    static let fontSize: CGFloat = CalendarTypography.cellContent * 0.77
    /// The chip box hugs its digits: 1pt each side, 1.2em tall, 2.5pt corners.
    static let horizontalPadding: CGFloat = 1
    static let boxHeightRatio: CGFloat = 1.2
    static let cornerRadius: CGFloat = 2.5
    /// A single time keeps 2pt clear of the row's edge; a range has no room to spare.
    static let singleTrailingMargin: CGFloat = 2

    let time: String
    let dutyColor: String?
    let isCurrentMonth: Bool

    var body: some View {
        let colors = DPCalendarCellStyle.timeChipColors(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        Text(verbatim: CalendarVisualLogic.wrappableScheduleTime(time))
            .font(DPFont.bold(size: Self.fontSize, relativeTo: .caption2).monospacedDigit())
            .tracking(Self.tracking)
            .foregroundStyle(colors.foreground)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, Self.horizontalPadding)
            .background(colors.background, in: RoundedRectangle(cornerRadius: Self.cornerRadius))
            .accessibilityLabel(Text(verbatim: time))
    }
}
