import SwiftUI
import UIKit

/// The title and clock share native line breaking, so the clock can use the last
/// title line's remaining space without disappearing behind the title limit.
struct DPCalendarScheduleLine: UIViewRepresentable {
    let title: String
    let time: String?
    var hasDetails = false
    var showsPrivateLock = false
    let dutyColor: String?
    let isCurrentMonth: Bool
    @ScaledMetric(relativeTo: .caption2) private var titleSize = CalendarTypography.cellContent
    @ScaledMetric(relativeTo: .caption2) private var timeSize = DPCalendarScheduleTime.fontSize

    func makeUIView(context: Context) -> DPCalendarScheduleLabel {
        let label = DPCalendarScheduleLabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.isAccessibilityElement = true
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: DPCalendarScheduleLabel, context: Context) {
        let titleFont = UIFont(name: DPFont.lightPostScriptName, size: titleSize)
            ?? .systemFont(ofSize: titleSize, weight: .light)
        let timeFont = UIFont(name: DPFont.boldPostScriptName, size: timeSize)
            ?? .systemFont(ofSize: timeSize, weight: .bold)
        let colors = DPCalendarCellStyle.timeChipColors(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)
        label.setContent(
            title: title,
            time: time,
            hasDetails: hasDetails,
            showsPrivateLock: showsPrivateLock,
            titleFont: titleFont,
            timeFont: timeFont,
            foreground: UIColor(DPCalendarCellStyle.primaryForeground(dutyColor: dutyColor, isCurrentMonth: isCurrentMonth)),
            timeForeground: UIColor(colors.foreground),
            timeBackground: UIColor(colors.background)
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: DPCalendarScheduleLabel, context: Context) -> CGSize? {
        guard let width = proposal.width, width > 0, width.isFinite else { return nil }
        return uiView.fittingSize(width: width)
    }
}

final class DPCalendarScheduleLabel: UILabel {
    private var titleText = NSAttributedString()
    private var timeText: NSAttributedString?
    private var titleAttributes: [NSAttributedString.Key: Any] = [:]

    func setContent(
        title: String, time: String?, hasDetails: Bool, showsPrivateLock: Bool,
        titleFont: UIFont, timeFont: UIFont, foreground: UIColor,
        timeForeground: UIColor, timeBackground: UIColor
    ) {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 1
        let attributes: [NSAttributedString.Key: Any] = [
            .font: titleFont, .foregroundColor: foreground, .kern: -0.3, .paragraphStyle: paragraph,
        ]
        titleAttributes = attributes
        let text = NSMutableAttributedString()
        if showsPrivateLock {
            text.append(symbol("lock", font: .systemFont(ofSize: titleFont.pointSize * 0.8, weight: .bold), color: UIColor(DPColor.dangerHover)))
            text.append(NSAttributedString(string: " ", attributes: attributes))
        }
        text.append(NSAttributedString(string: title, attributes: attributes))
        if hasDetails {
            text.append(NSAttributedString(string: " ", attributes: attributes))
            text.append(symbol("text.bubble", font: titleFont, color: foreground))
        }
        text.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: text.length))
        titleText = text
        timeText = time.map { time in
            let font = UIFont(descriptor: timeFont.fontDescriptor.addingAttributes([
                .featureSettings: [[
                    UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                    UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
                ]],
            ]), size: 0)
            // Keep each clock together, permitting a range to break after its tilde.
            let clocks = time.components(separatedBy: "~").map { $0.map(String.init).joined(separator: "\u{2060}") }
            return NSAttributedString(string: clocks.joined(separator: "~\u{200B}"), attributes: [
                .font: font, .foregroundColor: timeForeground, .backgroundColor: timeBackground,
                .kern: DPCalendarScheduleTime.tracking, .paragraphStyle: paragraph,
            ])
        }
        accessibilityLabel = [title, time].compactMap { $0 }.joined(separator: " ")
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func fittingSize(width: CGFloat) -> CGSize {
        attributedText = text(for: width)
        return CGSize(width: width, height: ceil(sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude)).height))
    }

    func text(for width: CGFloat) -> NSAttributedString {
        let storage = NSTextStorage(attributedString: titleText)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        container.maximumNumberOfLines = 2
        container.lineBreakMode = .byTruncatingTail
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let glyphs = layout.glyphRange(for: container)
        let text = NSMutableAttributedString(attributedString: titleText)
        if glyphs.length > 0 {
            let truncated = layout.truncatedGlyphRange(inLineFragmentForGlyphAt: NSMaxRange(glyphs) - 1)
            if truncated.location != NSNotFound {
                let end = layout.characterIndexForGlyph(at: truncated.location)
                text.deleteCharacters(in: NSRange(location: end, length: text.length - end))
                text.append(NSAttributedString(string: "…", attributes: titleAttributes))
            }
        }
        if let timeText {
            if text.length > 0 { text.append(NSAttributedString(string: " ", attributes: titleAttributes)) }
            text.append(timeText)
        }
        return text
    }

    private func symbol(_ name: String, font: UIFont, color: UIColor) -> NSAttributedString {
        let attachment = NSTextAttachment()
        attachment.image = UIImage(systemName: name, withConfiguration: UIImage.SymbolConfiguration(font: font))?
            .withTintColor(color, renderingMode: .alwaysOriginal)
        if let image = attachment.image {
            attachment.bounds = CGRect(x: 0, y: (font.capHeight - image.size.height) / 2, width: image.size.width, height: image.size.height)
        }
        let text = NSMutableAttributedString(attachment: attachment)
        text.addAttribute(.font, value: font, range: NSRange(location: 0, length: text.length))
        return text
    }
}
