import SwiftUI
import UIKit

/// The title and clock share one native label, so the clock can use the last title
/// line's remaining space without disappearing behind the title limit. The clock sits
/// against the trailing edge, on that line when it fits beside the title, otherwise on
/// its own line.
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
    /// Marks the clock and carries its box colour; the label draws the box itself so it
    /// can be shorter than the line and inset from the digits.
    static let timeChip = NSAttributedString.Key("DPCalendarScheduleTimeChip")
    private static let inset = DPCalendarScheduleTime.horizontalPadding

    private var titleText = NSAttributedString()
    private var timeText: NSAttributedString?
    private var timeWidth: CGFloat = 0
    private var timeFont = UIFont.systemFont(ofSize: DPCalendarScheduleTime.fontSize)
    private var titleAttributes: [NSAttributedString.Key: Any] = [:]
    private var paragraph = NSParagraphStyle()

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
        self.paragraph = paragraph
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
            self.timeFont = font
            return NSAttributedString(string: clocks.joined(separator: "~\u{200B}"), attributes: [
                .font: font, .foregroundColor: timeForeground, Self.timeChip: timeBackground,
                .kern: DPCalendarScheduleTime.tracking, .paragraphStyle: paragraph,
            ])
        }
        timeWidth = timeText.map { ceil($0.size().width) } ?? 0
        accessibilityLabel = [title, time].compactMap { $0 }.joined(separator: " ")
        invalidateIntrinsicContentSize()
        setNeedsLayout()
    }

    func fittingSize(width: CGFloat) -> CGSize {
        attributedText = text(for: width)
        return CGSize(width: width, height: ceil(Layout(text: attributedText, width: width, timeFont: timeFont).height))
    }

    /// The clock's boxes, one per line it occupies, in the label's coordinates.
    func chipBoxes(width: CGFloat) -> [CGRect] {
        let layout = Layout(text: text(for: width), width: width, timeFont: timeFont)
        return layout.boxes.map { $0.rect.offsetBy(dx: 0, dy: layout.top) }
    }

    override func drawText(in rect: CGRect) {
        guard let attributedText, let context = UIGraphicsGetCurrentContext() else { return }
        let layout = Layout(text: attributedText, width: bounds.width, timeFont: timeFont)
        for box in layout.boxes {
            box.color.setFill()
            UIBezierPath(
                roundedRect: box.rect.offsetBy(dx: 0, dy: layout.top),
                cornerRadius: DPCalendarScheduleTime.cornerRadius
            ).fill()
        }
        context.saveGState()
        defer { context.restoreGState() }
        layout.manager.drawGlyphs(
            forGlyphRange: layout.manager.glyphRange(for: layout.container),
            at: CGPoint(x: 0, y: layout.top)
        )
    }

    /// Lays the text out as it is drawn, so the boxes sit exactly behind their digits.
    private struct Layout {
        let manager = NSLayoutManager()
        let container: NSTextContainer
        let storage: NSTextStorage
        let boxes: [(rect: CGRect, color: UIColor)]
        /// Moves everything down when a box on the first line reaches above the text.
        let top: CGFloat
        let height: CGFloat

        init(text: NSAttributedString?, width: CGFloat, timeFont: UIFont) {
            let manager = manager
            let storage = NSTextStorage(attributedString: text ?? NSAttributedString())
            let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
            container.lineFragmentPadding = 0
            manager.addTextContainer(container)
            storage.addLayoutManager(manager)
            let glyphs = manager.glyphRange(for: container)
            var boxes: [(rect: CGRect, color: UIColor)] = []
            storage.enumerateAttribute(DPCalendarScheduleLabel.timeChip, in: NSRange(location: 0, length: storage.length)) { value, range, _ in
                guard let color = value as? UIColor else { return }
                let chip = manager.glyphRange(forCharacterRange: range, actualCharacterRange: nil)
                manager.enumerateLineFragments(forGlyphRange: glyphs) { fragment, _, _, line, _ in
                    var visible = NSIntersectionRange(line, chip)
                    // Zero-width break hints at a line's end do not widen the box.
                    while visible.length > 0, Self.isBreakHint(storage, manager, glyph: NSMaxRange(visible) - 1) {
                        visible.length -= 1
                    }
                    guard visible.length > 0 else { return }
                    let digits = manager.boundingRect(forGlyphRange: visible, in: container)
                    let baseline = fragment.minY + manager.location(forGlyphAt: visible.location).y
                    let height = timeFont.pointSize * DPCalendarScheduleTime.boxHeightRatio
                    boxes.append((CGRect(
                        x: digits.minX - DPCalendarScheduleLabel.inset,
                        y: baseline - timeFont.capHeight / 2 - height / 2,
                        width: digits.width + DPCalendarScheduleLabel.inset * 2,
                        height: height
                    ), color))
                }
            }
            self.storage = storage
            self.container = container
            self.boxes = boxes
            top = max(0, -(boxes.map(\.rect.minY).min() ?? 0))
            height = max(manager.usedRect(for: container).maxY, boxes.map(\.rect.maxY).max() ?? 0) + top
        }

        private static func isBreakHint(_ storage: NSTextStorage, _ manager: NSLayoutManager, glyph: Int) -> Bool {
            let range = manager.characterRange(forGlyphRange: NSRange(location: glyph, length: 1), actualGlyphRange: nil)
            return ["\u{200B}", "\u{2060}"].contains((storage.string as NSString).substring(with: range))
        }
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
        var lastLineWidth: CGFloat = 0
        if glyphs.length > 0 {
            let lastGlyph = NSMaxRange(glyphs) - 1
            let truncated = layout.truncatedGlyphRange(inLineFragmentForGlyphAt: lastGlyph)
            if truncated.location != NSNotFound {
                let end = layout.characterIndexForGlyph(at: truncated.location)
                text.deleteCharacters(in: NSRange(location: end, length: text.length - end))
                text.append(NSAttributedString(string: "…", attributes: titleAttributes))
                lastLineWidth = Self.lastLineWidth(of: text, width: width)
            } else {
                lastLineWidth = layout.lineFragmentUsedRect(forGlyphAt: lastGlyph, effectiveRange: nil).width
            }
        }
        guard let timeText else { return text }
        guard text.length > 0 else { return trailing(timeText) }

        let gap = NSAttributedString(string: " ", attributes: titleAttributes).size().width
        if lastLineWidth + gap + Self.inset * 2 + trailingMargin + timeWidth <= width {
            // A right tab stop one inset from the edge puts the clock's box flush right on the title's line.
            let style = paragraph.mutableCopy() as! NSMutableParagraphStyle
            style.tabStops = [NSTextTab(textAlignment: .right, location: width - Self.inset - trailingMargin)]
            text.append(NSAttributedString(string: "\t", attributes: titleAttributes))
            text.append(timeText)
            text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        } else {
            text.append(NSAttributedString(string: "\n", attributes: titleAttributes))
            text.append(trailing(timeText))
        }
        return text
    }

    private var trailingMargin: CGFloat {
        timeText?.string.contains("~") == true ? 0 : DPCalendarScheduleTime.singleTrailingMargin
    }

    private func trailing(_ time: NSAttributedString) -> NSAttributedString {
        let style = paragraph.mutableCopy() as! NSMutableParagraphStyle
        style.alignment = .right
        // Room for the box on both sides, so a range breaks only when its box outgrows the row.
        style.firstLineHeadIndent = Self.inset
        style.headIndent = Self.inset
        style.tailIndent = -(Self.inset + trailingMargin)
        let text = NSMutableAttributedString(attributedString: time)
        text.addAttribute(.paragraphStyle, value: style, range: NSRange(location: 0, length: text.length))
        return text
    }

    private static func lastLineWidth(of text: NSAttributedString, width: CGFloat) -> CGFloat {
        let storage = NSTextStorage(attributedString: text)
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        let glyphs = layout.glyphRange(for: container)
        guard glyphs.length > 0 else { return 0 }
        return layout.lineFragmentUsedRect(forGlyphAt: NSMaxRange(glyphs) - 1, effectiveRange: nil).width
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
