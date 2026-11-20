import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
private final class TitleHeights {
    var values: [Int: CGFloat] = [:]
}

/// Lays out real month tiles at the iPhone 13 mini width and measures how tall a schedule
/// title is drawn, so a title squeezed to one truncated line is caught.
@MainActor
struct CalendarScheduleTitleLayoutTests {
    private struct Item {
        let title: String
    }

    private struct TileID: Identifiable {
        let id: Int
    }

    /// A tile placed at exactly its own measured height (the tallest of its row) must still
    /// draw a leading title on the same two lines as a tile with nothing else.
    @Test
    func aLeadingTitleKeepsBothLinesWhenItsTileIsTheTallestOfTheRow() {
        let lead = Item(title: "엄마 생신 대전")
        let tiles: [[Item]] = [
            [], [lead], [lead], [], [], [], [],
            [], [lead, Item(title: "점심 약속 장소 예약")], [], [], [], [], [],
        ]
        let heights = layOut(tiles)

        let alone = heights.values[1] ?? 0
        #expect(alone > 20, "The lone title wraps onto two lines")
        #expect(heights.values[2] == alone)
        #expect(heights.values[8] == alone, "A busier tile must not truncate the title to one line")
    }

    /// A month tile's time line may break only after a range's "~", never inside "12:00".
    /// The time is laid out in a real tile at the iPhone 13 mini width, and its breaks are
    /// read back with TextKit at that same width.
    @Test
    func aTimeRangeWrapsOnlyAfterItsTildeInAMonthTile() throws {
        let measured = layOutTimes(["12:00~13:00", "12:00"])
        let width = try #require(measured.values[-1])
        let range = try #require(measured.values[0])
        let single = try #require(measured.values[1])

        // The chip's text sits inside its horizontal padding.
        let textWidth = width - DPCalendarScheduleTime.horizontalPadding * 2
        #expect(timeLines("12:00~13:00", width: textWidth) == ["12:00~\u{200B}", "13:00"])
        #expect(timeLines("~13:00", width: textWidth) == ["~13:00"])
        #expect(timeLines("12:00", width: textWidth) == ["12:00"])
        #expect(range > single * 1.5 && range < single * 2.5, "A range takes exactly two lines in the tile")
    }

    /// Index -1 holds the width a tile gives its item row; the others hold each time's height.
    private func layOutTimes(_ times: [String]) -> TitleHeights {
        let measured = TitleHeights()
        let grid = CalendarMonthCellGrid(items: (0..<7).map { TileID(id: $0) }) { index, _ in
            DPCalendarDayTile(
                day: index + 1,
                weekdayIndex: index,
                dutyColor: nil,
                isCurrentMonth: true,
                isToday: false
            ) {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    if index < times.count {
                        DPCalendarItemRow(showsRule: false, rule: .gray) {
                            DPCalendarScheduleTime(time: times[index], dutyColor: nil, isCurrentMonth: true)
                                .background {
                                    GeometryReader { proxy in
                                        Color.clear
                                            .onAppear { measured.values[index] = proxy.size.height }
                                            .onChange(of: proxy.size.height) { _, height in
                                                measured.values[index] = height
                                            }
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background {
                                    GeometryReader { proxy in
                                        Color.clear
                                            .onAppear { measured.values[-1] = proxy.size.width }
                                            .onChange(of: proxy.size.width) { _, width in
                                                measured.values[-1] = width
                                            }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DPSpacing.small)
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.dynamicTypeSize, .large)

        let host = UIHostingController(rootView: grid)
        host.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        host.view.layoutIfNeeded()
        return measured
    }

    /// The lines TextKit breaks a cell time into, set in the time line's font.
    private func timeLines(_ time: String, width: CGFloat) -> [String] {
        let text = CalendarVisualLogic.wrappableScheduleTime(time)
        let base = UIFont(name: DPFont.boldPostScriptName, size: DPCalendarScheduleTime.fontSize)
            ?? .systemFont(ofSize: DPCalendarScheduleTime.fontSize, weight: .bold)
        let font = UIFont(descriptor: base.fontDescriptor.addingAttributes([
            .featureSettings: [[
                UIFontDescriptor.FeatureKey.type: kNumberSpacingType,
                UIFontDescriptor.FeatureKey.selector: kMonospacedNumbersSelector,
            ]],
        ]), size: 0)
        let storage = NSTextStorage(string: text, attributes: [.font: font, .kern: DPCalendarScheduleTime.tracking])
        let layout = NSLayoutManager()
        let container = NSTextContainer(size: CGSize(width: width, height: .greatestFiniteMagnitude))
        container.lineFragmentPadding = 0
        layout.addTextContainer(container)
        storage.addLayoutManager(layout)
        var lines: [String] = []
        layout.enumerateLineFragments(forGlyphRange: layout.glyphRange(for: container)) { _, _, _, glyphs, _ in
            let characters = layout.characterRange(forGlyphRange: glyphs, actualGlyphRange: nil)
            lines.append((text as NSString).substring(with: characters))
        }
        return lines
    }

    private func layOut(_ tiles: [[Item]]) -> TitleHeights {
        let heights = TitleHeights()
        let grid = CalendarMonthCellGrid(items: tiles.indices.map { TileID(id: $0) }) { index, _ in
            DPCalendarDayTile(
                day: index + 1,
                weekdayIndex: index % 7,
                dutyColor: nil,
                isCurrentMonth: true,
                isToday: false
            ) {
                EmptyView()
            } content: {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(tiles[index].enumerated()), id: \.offset) { offset, item in
                        DPCalendarItemRow(showsRule: offset > 0, rule: .gray) {
                            title(item)
                                .background {
                                    if offset == 0 {
                                        GeometryReader { proxy in
                                            Color.clear
                                                .onAppear { heights.values[index] = proxy.size.height }
                                                .onChange(of: proxy.size.height) { _, height in
                                                    heights.values[index] = height
                                                }
                                        }
                                    }
                                }
                        }
                    }
                }
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .padding(.horizontal, DPSpacing.small)
        .frame(maxHeight: .infinity, alignment: .top)
        .environment(\.dynamicTypeSize, .large)

        let host = UIHostingController(rootView: grid)
        host.view.frame = CGRect(x: 0, y: 0, width: 375, height: 812)
        let window = UIWindow(frame: host.view.frame)
        window.rootViewController = host
        window.makeKeyAndVisible()
        defer { window.isHidden = true }
        host.view.layoutIfNeeded()
        RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.2))
        host.view.layoutIfNeeded()
        return heights
    }

    private func title(_ item: Item) -> some View {
        Text(verbatim: item.title)
        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
        .tracking(-0.3)
        .lineSpacing(1)
        .lineLimit(2)
        .truncationMode(.tail)
    }
}
