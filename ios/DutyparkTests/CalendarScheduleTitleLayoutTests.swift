import SwiftUI
import Testing
import UIKit
@testable import Dutypark

@MainActor
private final class TitleHeights {
    var values: [Int: CGFloat] = [:]
}

/// Lays out real month tiles at the iPhone 13 mini width and measures how tall a multi-day
/// title is drawn, so a title squeezed to one truncated line is caught.
@MainActor
struct CalendarScheduleTitleLayoutTests {
    private struct Item {
        let title: String
        let daysFromStart: Int
        let totalDays: Int
    }

    private struct TileID: Identifiable {
        let id: Int
    }

    /// A tile placed at exactly its own measured height (the tallest of its row) must still
    /// draw a leading multi-day title on the same two lines as a tile with nothing else.
    @Test
    func aMultiDayTitleKeepsBothLinesWhenItsTileIsTheTallestOfTheRow() {
        let run = Item(title: "엄마 대전", daysFromStart: 1, totalDays: 3)
        let tiles: [[Item]] = [
            [], [run], [Item(title: "엄마 대전", daysFromStart: 2, totalDays: 3)], [], [], [], [],
            [], [run, Item(title: "점심 약속 장소 예약", daysFromStart: 1, totalDays: 1)], [], [], [], [], [],
        ]
        let heights = layOut(tiles)

        let alone = heights.values[1] ?? 0
        #expect(alone > 20, "The lone title wraps onto two lines")
        #expect(heights.values[2] == alone)
        #expect(heights.values[8] == alone, "A busier tile must not truncate the title to one line")
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
                        DPCalendarItemRow(
                            showsRule: offset > 0,
                            rule: .gray,
                            span: DPCalendarSpan(daysFromStart: item.daysFromStart, totalDays: item.totalDays),
                            spanColor: .black
                        ) {
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
        DPCalendarScheduleTitle.text(
            Text(verbatim: item.title),
            daysFromStart: item.daysFromStart,
            totalDays: item.totalDays,
            counterColor: .gray
        )
        .font(DPFont.light(size: CalendarTypography.cellContent, relativeTo: .caption2))
        .tracking(-0.3)
        .lineSpacing(1)
        .lineLimit(2)
        .truncationMode(.tail)
    }
}
