import CoreGraphics
import SwiftUI
import Testing
@testable import Dutypark

struct CalendarSpanConnectionTests {
    @Test func connectsOnlyConsecutiveDaysInsideTheSameWeek() {
        #expect(CalendarSpanConnection.canConnect(leftIndex: 2, rightIndex: 3, leftDay: 1, rightDay: 2))
        #expect(!CalendarSpanConnection.canConnect(leftIndex: 6, rightIndex: 7, leftDay: 1, rightDay: 2))
        #expect(!CalendarSpanConnection.canConnect(leftIndex: 2, rightIndex: 4, leftDay: 1, rightDay: 2))
        #expect(!CalendarSpanConnection.canConnect(leftIndex: 2, rightIndex: 3, leftDay: 1, rightDay: 1))
    }

    @Test func curveStaysInsideTheEmptyCellEdgePadding() {
        let inset = CalendarSpanConnection.edgeInset(barWidth: 100, strokeWidth: 2.5)
        #expect(inset == 1.75)
        #expect(inset + 2.5 / 2 <= DPCalendarCellStyle.cellHorizontalPadding)
        #expect(CalendarSpanConnection.edgeInset(barWidth: 1, strokeWidth: 2.5) <= 1.0 / 3)
    }

    @Test func equalHeightFractionalCoordinatesKeepTheJoinOnTheSameBaseline() {
        let start = CGPoint(x: 98.125, y: 42.625)
        let end = CGPoint(x: 105.875, y: 42.625)
        let controls = CalendarSpanConnection.controlPoints(from: start, to: end)
        #expect(controls.0.y == start.y)
        #expect(controls.1.y == end.y)
        #expect(controls.0.y == controls.1.y)
    }

    @Test func curveHasHorizontalTangentsAtBothEnds() {
        let controls = CalendarSpanConnection.controlPoints(from: CGPoint(x: 10, y: 20), to: CGPoint(x: 30, y: 45))
        #expect(controls.0 == CGPoint(x: 20, y: 20))
        #expect(controls.1 == CGPoint(x: 20, y: 45))
    }
}

@MainActor
private final class SpanBounds {
    var rects: [Int: CGRect] = [:]
    var tiles: [Int: CGRect] = [:]
}

private struct TileBoundsKey: PreferenceKey {
    static let defaultValue: [Int: Anchor<CGRect>] = [:]
    static func reduce(value: inout [Int: Anchor<CGRect>], nextValue: () -> [Int: Anchor<CGRect>]) {
        value.merge(nextValue(), uniquingKeysWith: { _, next in next })
    }
}

@MainActor
struct CalendarSpanAnchorLayoutTests {
    @Test(arguments: [100.0, 100.25], [0.0, 16.0])
    func measuredBarsIncludeContinuationEdgesAndDifferentContentHeights(width: Double, holidayHeight: Double) {
        let values = SpanBounds()
        let id = UUID()
        let grid = HStack(alignment: .top, spacing: 2) {
            ForEach(0..<3) { index in
                DPCalendarDayTile(day: index + 1, weekdayIndex: index, dutyColor: nil, isCurrentMonth: true, isToday: false) {
                    EmptyView()
                } content: {
                    VStack(spacing: 0) {
                        if index == 1 && holidayHeight > 0 { Text("Holiday").frame(height: holidayHeight) }
                        DPCalendarItemRow(showsRule: false, rule: .clear,
                            span: DPCalendarSpan(daysFromStart: index + 1, totalDays: 3),
                            spanColor: .black, spanID: id, spanDay: index + 1) {
                            Text("Run").frame(height: 14)
                        }
                    }
                }
                .environment(\.calendarSpanCellIndex, index)
                .frame(width: width)
                .anchorPreference(key: TileBoundsKey.self, value: .bounds) { [index: $0] }
            }
        }
        .calendarSpanConnections()
        .overlayPreferenceValue(CalendarSpanAnchors.self) { anchors in
            GeometryReader { proxy in
                Canvas { _, _ in
                    values.rects = Dictionary(uniqueKeysWithValues: anchors.map { ($0.index, proxy[$0.bounds]) })
                }
            }
        }
        .overlayPreferenceValue(TileBoundsKey.self) { tiles in
            GeometryReader { proxy in
                Canvas { _, _ in values.tiles = tiles.mapValues { proxy[$0] } }
            }
        }
        let scale: CGFloat = 3
        let renderer = ImageRenderer(content: grid
            .frame(width: width * 3 + 4, height: 160, alignment: .topLeading)
            .environment(\.colorScheme, .light)
            .environment(\.displayScale, scale)
            .background(Color.white))
        renderer.scale = scale
        guard let image = renderer.cgImage else { Issue.record("Canvas snapshot missing"); return }
        #expect(values.rects.count == 3)
        guard let first = values.rects[0], let middle = values.rects[1], let last = values.rects[2] else { return }
        guard let firstTile = values.tiles[0], let middleTile = values.tiles[1], let lastTile = values.tiles[2] else {
            Issue.record("All tile bounds must resolve")
            return
        }
        // SwiftUI aligns the actual tile edges to display pixels even when proposed widths are fractional.
        #expect(abs(first.minX - (firstTile.minX + DPCalendarCellStyle.cellHorizontalPadding)) < 0.1)
        #expect(abs(first.maxX - firstTile.maxX) < 0.1)
        #expect(abs(middle.minX - middleTile.minX) < 0.1)
        #expect(abs(middle.maxX - middleTile.maxX) < 0.1)
        #expect(abs(last.minX - lastTile.minX) < 0.1)
        #expect(abs(last.maxX - (lastTile.maxX - DPCalendarCellStyle.cellHorizontalPadding)) < 0.1)
        if holidayHeight > 0 {
            #expect(middle.midY > first.midY + 10)
        } else {
            #expect(abs(middle.midY - first.midY) < 0.1)
            let cgImage = image
            var pixels = [UInt8](repeating: 0, count: cgImage.width * cgImage.height * 4)
            let context = CGContext(data: &pixels, width: cgImage.width, height: cgImage.height,
                bitsPerComponent: 8, bytesPerRow: cgImage.width * 4,
                space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(cgImage, in: CGRect(x: 0, y: 0, width: cgImage.width, height: cgImage.height))
            let y = Int(first.midY * scale)
            let left = Int((first.maxX - 5) * scale)
            let right = Int((middle.minX + 5) * scale)
            guard y >= 0, y < cgImage.height, left >= 0, right < cgImage.width else {
                Issue.record("Measured bar must be inside the snapshot")
                return
            }
            let interior = Int((first.midX) * scale)
            #expect(pixels[(y * cgImage.width + interior) * 4] < 8, "The known interior of the Canvas bar must be visible")
            let values = (left...right).map { x in Int(pixels[(y * cgImage.width + x) * 4]) }
            #expect(values.max()! < 8, "The black bar must remain solid across fractional bar/curve joints: \(values)")
            #expect((left...right).allSatisfy { pixels[(y * cgImage.width + $0) * 4 + 3] == 255 },
                "The sampled connection must be opaque")
        }
        #expect(abs(first.midY - last.midY) < 0.1)
    }
}
