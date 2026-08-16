import Foundation
import SwiftUI

nonisolated struct DPLongFormListItem: Equatable, Sendable {
    let marker: String
    let text: String
}

nonisolated enum DPLongFormBlock: Equatable, Sendable {
    case heading(level: Int, text: String)
    case paragraph(String)
    case orderedList([DPLongFormListItem])
    case unorderedList([DPLongFormListItem])
    case table(headers: [String], rows: [[String]])
    case separator
}

nonisolated enum DPLongFormMarkdownParser {
    static func parse(_ markdown: String) -> [DPLongFormBlock] {
        let lines = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .split(separator: "\n", omittingEmptySubsequences: false)
            .map(String.init)
        var blocks: [DPLongFormBlock] = []
        var index = 0

        while index < lines.count {
            let line = lines[index]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                index += 1
                continue
            }

            if let heading = heading(from: trimmed) {
                blocks.append(.heading(level: heading.level, text: heading.text))
                index += 1
                continue
            }

            if isSeparator(trimmed) {
                blocks.append(.separator)
                index += 1
                continue
            }

            if index + 1 < lines.count,
               let headers = tableCells(from: trimmed),
               isTableSeparator(lines[index + 1], expectedColumnCount: headers.count) {
                index += 2
                var rows: [[String]] = []
                while index < lines.count,
                      let row = tableCells(from: lines[index]),
                      !row.isEmpty {
                    rows.append(normalized(row, columnCount: headers.count))
                    index += 1
                }
                blocks.append(.table(headers: headers, rows: rows))
                continue
            }

            if orderedItem(from: trimmed) != nil {
                var items: [DPLongFormListItem] = []
                while index < lines.count,
                      let item = orderedItem(
                        from: lines[index].trimmingCharacters(in: .whitespaces)
                      ) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.orderedList(items))
                continue
            }

            if unorderedItem(from: trimmed) != nil {
                var items: [DPLongFormListItem] = []
                while index < lines.count,
                      let item = unorderedItem(
                        from: lines[index].trimmingCharacters(in: .whitespaces)
                      ) {
                    items.append(item)
                    index += 1
                }
                blocks.append(.unorderedList(items))
                continue
            }

            var paragraphLines = [line.trimmingCharacters(in: .whitespaces)]
            index += 1
            while index < lines.count {
                let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                guard !candidate.isEmpty,
                      heading(from: candidate) == nil,
                      !isSeparator(candidate),
                      orderedItem(from: candidate) == nil,
                      unorderedItem(from: candidate) == nil,
                      !startsTable(at: index, lines: lines)
                else { break }
                paragraphLines.append(candidate)
                index += 1
            }
            blocks.append(.paragraph(paragraphLines.joined(separator: "\n")))
        }

        return blocks
    }

    private static func heading(from line: String) -> (level: Int, text: String)? {
        let prefix = line.prefix { $0 == "#" }
        guard (1...6).contains(prefix.count),
              line.dropFirst(prefix.count).first?.isWhitespace == true
        else { return nil }
        let text = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : (prefix.count, text)
    }

    private static func orderedItem(from line: String) -> DPLongFormListItem? {
        guard let dot = line.firstIndex(of: "."), dot != line.startIndex else { return nil }
        let number = line[..<dot]
        guard number.allSatisfy(\.isNumber) else { return nil }
        let afterDot = line.index(after: dot)
        guard afterDot < line.endIndex, line[afterDot].isWhitespace else { return nil }
        let text = line[line.index(after: afterDot)...].trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .init(marker: "\(number).", text: text)
    }

    private static func unorderedItem(from line: String) -> DPLongFormListItem? {
        guard line.count > 2,
              ["-", "*", "+"].contains(String(line.first!)),
              line[line.index(after: line.startIndex)].isWhitespace
        else { return nil }
        let text = line.dropFirst(2).trimmingCharacters(in: .whitespaces)
        return text.isEmpty ? nil : .init(marker: "•", text: text)
    }

    private static func isSeparator(_ line: String) -> Bool {
        let compact = line.filter { !$0.isWhitespace }
        guard compact.count >= 3, let first = compact.first, ["-", "*", "_"].contains(first) else {
            return false
        }
        return compact.allSatisfy { $0 == first }
    }

    private static func startsTable(at index: Int, lines: [String]) -> Bool {
        guard index + 1 < lines.count,
              let headers = tableCells(from: lines[index])
        else { return false }
        return isTableSeparator(lines[index + 1], expectedColumnCount: headers.count)
    }

    private static func tableCells(from line: String) -> [String]? {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard trimmed.contains("|") else { return nil }
        let content = trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "|"))
        let cells = content
            .split(separator: "|", omittingEmptySubsequences: false)
            .map { $0.trimmingCharacters(in: .whitespaces) }
        return cells.count >= 2 ? cells : nil
    }

    private static func isTableSeparator(_ line: String, expectedColumnCount: Int) -> Bool {
        guard let cells = tableCells(from: line), cells.count == expectedColumnCount else {
            return false
        }
        return cells.allSatisfy { cell in
            let dashes = cell.replacingOccurrences(of: ":", with: "")
            return dashes.count >= 3 && dashes.allSatisfy { $0 == "-" }
        }
    }

    private static func normalized(_ row: [String], columnCount: Int) -> [String] {
        if row.count == columnCount { return row }
        if row.count > columnCount { return Array(row.prefix(columnCount)) }
        return row + Array(repeating: "", count: columnCount - row.count)
    }
}

nonisolated enum DPLongFormDocumentLayout {
    static let horizontalPadding: CGFloat = 20
    static let verticalPadding: CGFloat = 16
}

nonisolated enum DPLongFormDocumentStyle: Equatable, Sendable {
    case regular
    case compact

    var bodySize: CGFloat { self == .regular ? 16 : 13 }
    var lineSpacing: CGFloat { self == .regular ? 6 : 3 }
    var blockSpacing: CGFloat { self == .regular ? 16 : 9 }
    var listSpacing: CGFloat { self == .regular ? 9 : 5 }
    var contentPadding: CGFloat { self == .regular ? 14 : 9 }
}

struct DPLongFormDocument: View {
    let content: String
    var style: DPLongFormDocumentStyle = .regular

    private var blocks: [DPLongFormBlock] {
        DPLongFormMarkdownParser.parse(content)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: style.blockSpacing) {
            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                blockView(block, index: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .textSelection(.enabled)
    }

    @ViewBuilder
    private func blockView(_ block: DPLongFormBlock, index: Int) -> some View {
        switch block {
        case let .heading(level, text):
            Text(inlineMarkdown(text))
                .font(headingFont(level: level))
                .foregroundStyle(DPColor.textPrimary)
                .lineSpacing(style.lineSpacing / 2)
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityAddTraits(.isHeader)
                .accessibilityIdentifier("dp.longForm.heading.\(index)")

        case let .paragraph(text):
            readableText(text)
                .accessibilityIdentifier("dp.longForm.paragraph.\(index)")

        case let .orderedList(items), let .unorderedList(items):
            Grid(
                alignment: .leading,
                horizontalSpacing: style == .regular ? 8 : 5,
                verticalSpacing: style.listSpacing
            ) {
                ForEach(Array(items.enumerated()), id: \.offset) { itemIndex, item in
                    listRow(item)
                        .accessibilityIdentifier("dp.longForm.list.\(index).\(itemIndex)")
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

        case let .table(headers, rows):
            VStack(alignment: .leading, spacing: style.listSpacing) {
                ForEach(Array(rows.enumerated()), id: \.offset) { rowIndex, row in
                    tableRow(headers: headers, values: row)
                        .accessibilityIdentifier("dp.longForm.table.\(index).row.\(rowIndex)")
                }
            }

        case .separator:
            Divider().overlay(DPColor.borderPrimary)
        }
    }

    private func readableText(_ text: String) -> some View {
        Text(inlineMarkdown(text))
            .font(bodyFont)
            .foregroundStyle(DPColor.textSecondary)
            .lineSpacing(style.lineSpacing)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func listRow(_ item: DPLongFormListItem) -> some View {
        GridRow(alignment: .firstTextBaseline) {
            Text(item.marker)
                .font(bodyFont)
                .foregroundStyle(DPColor.textMuted)
                .gridColumnAlignment(.trailing)
                .accessibilityHidden(true)
            readableText(item.text)
                .gridColumnAlignment(.leading)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(item.marker) \(plainText(item.text))")
    }

    private func tableRow(headers: [String], values: [String]) -> some View {
        VStack(alignment: .leading, spacing: style.listSpacing) {
            ForEach(headers.indices, id: \.self) { column in
                let value = column < values.count ? values[column] : ""
                if !value.isEmpty {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(inlineMarkdown(headers[column]))
                            .font(tableLabelFont)
                            .foregroundStyle(DPColor.textMuted)
                            .fixedSize(horizontal: false, vertical: true)
                        readableText(value)
                    }
                }
            }
        }
        .padding(style.contentPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(DPColor.backgroundSecondary, in: RoundedRectangle(cornerRadius: DPRadius.standard))
        .overlay {
            RoundedRectangle(cornerRadius: DPRadius.standard)
                .stroke(DPColor.borderPrimary, lineWidth: DPChrome.borderWidth)
        }
        .accessibilityElement(children: .combine)
    }

    private var bodyFont: Font {
        style == .regular
            ? DPFont.light(size: style.bodySize, relativeTo: .body)
            : DPFont.light(size: style.bodySize, relativeTo: .caption)
    }

    private var tableLabelFont: Font {
        style == .regular
            ? DPFont.bold(size: 12, relativeTo: .caption)
            : DPFont.bold(size: 11, relativeTo: .caption2)
    }

    private func headingFont(level: Int) -> Font {
        if style == .compact {
            return DPFont.bold(size: level <= 2 ? 14 : 13, relativeTo: .subheadline)
        }
        switch level {
        case 1: return DPTypography.sectionTitle
        case 2: return DPTypography.heading
        default: return DPFont.bold(size: 16, relativeTo: .body)
        }
    }

    private func inlineMarkdown(_ value: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )
        return (try? AttributedString(markdown: value, options: options)) ?? AttributedString(value)
    }

    private func plainText(_ value: String) -> String {
        String(inlineMarkdown(value).characters)
    }
}
