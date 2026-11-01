import SwiftUI

nonisolated enum CalendarSpanConnection {
    static func canConnect(leftIndex: Int, rightIndex: Int, leftDay: Int, rightDay: Int) -> Bool {
        leftIndex / 7 == rightIndex / 7 && rightIndex == leftIndex + 1 && rightDay == leftDay + 1
    }

    static func edgeInset(barWidth: CGFloat, strokeWidth: CGFloat) -> CGFloat {
        min(max(0, DPCalendarCellStyle.cellHorizontalPadding - strokeWidth / 2), barWidth / 3)
    }

    static func controlPoints(from start: CGPoint, to end: CGPoint) -> (CGPoint, CGPoint) {
        let middle = (start.x + end.x) / 2
        return (CGPoint(x: middle, y: start.y), CGPoint(x: middle, y: end.y))
    }
}

nonisolated private struct CalendarSpanCellIndex: EnvironmentKey {
    static let defaultValue: Int? = nil
}

extension EnvironmentValues {
    nonisolated var calendarSpanCellIndex: Int? {
        get { self[CalendarSpanCellIndex.self] }
        set { self[CalendarSpanCellIndex.self] = newValue }
    }
}

nonisolated struct CalendarSpanAnchor {
    let id: ScheduleID
    let index: Int
    let day: Int
    let span: DPCalendarSpan
    let color: Color
    let bounds: Anchor<CGRect>
}

nonisolated struct CalendarSpanAnchors: PreferenceKey {
    static let defaultValue: [CalendarSpanAnchor] = []
    static func reduce(value: inout [CalendarSpanAnchor], nextValue: () -> [CalendarSpanAnchor]) {
        value.append(contentsOf: nextValue())
    }
}

private struct CalendarSpanDrawing: View {
    let anchors: [CalendarSpanAnchor]
    let proxy: GeometryProxy

    var body: some View {
        Canvas { context, size in
            let visible = anchors.filter {
                let rect = proxy[$0.bounds]
                return rect.width > 0 && rect.height > 0 && rect.minX.isFinite && rect.minY.isFinite
            }
            for first in visible where !visible.contains(where: { connects($0, first) }) {
                let firstRect = proxy[first.bounds]
                var path = Path()
                var item = first
                var start = CGPoint(x: firstRect.minX + (first.span.isStart ? firstRect.height / 2 : 0), y: firstRect.midY)
                let origin = start
                var stops: [(Color, CGFloat)] = [(first.color, start.x)]
                path.move(to: start)
                while true {
                    let rect = proxy[item.bounds]
                    let next = visible.first { connects(item, $0) }
                    let inset = CalendarSpanConnection.edgeInset(barWidth: rect.width, strokeWidth: rect.height)
                    let end = CGPoint(x: rect.maxX - (next == nil ? (item.span.isEnd ? rect.height / 2 : 0) : inset), y: rect.midY)
                    path.addLine(to: end)
                    stops.append((item.color, end.x))
                    guard let next else {
                        // Stroke the whole run once: separate antialiased butt caps leave a hairline seam.
                        let width = end.x - origin.x
                        let gradient = Gradient(stops: stops.map { color, x in
                            .init(color: color, location: width > 0 ? (x - origin.x) / width : 0)
                        })
                        var runContext = context
                        runContext.clip(to: Path(CGRect(x: firstRect.minX, y: 0,
                            width: rect.maxX - firstRect.minX, height: size.height)))
                        runContext.stroke(path, with: .linearGradient(gradient,
                            startPoint: origin, endPoint: CGPoint(x: end.x, y: origin.y)),
                            style: StrokeStyle(lineWidth: firstRect.height, lineCap: .round))
                        break
                    }
                    let nextRect = proxy[next.bounds]
                    start = CGPoint(x: nextRect.minX + CalendarSpanConnection.edgeInset(barWidth: nextRect.width, strokeWidth: nextRect.height), y: nextRect.midY)
                    let controls = CalendarSpanConnection.controlPoints(from: end, to: start)
                    path.addCurve(to: start, control1: controls.0, control2: controls.1)
                    stops.append((next.color, start.x))
                    item = next
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func connects(_ left: CalendarSpanAnchor, _ right: CalendarSpanAnchor) -> Bool {
        left.id == right.id && !left.span.isEnd && !right.span.isStart
            && CalendarSpanConnection.canConnect(leftIndex: left.index, rightIndex: right.index, leftDay: left.day, rightDay: right.day)
    }


}

extension View {
    func calendarSpanConnections() -> some View {
        overlayPreferenceValue(CalendarSpanAnchors.self) { anchors in
            GeometryReader { proxy in
                CalendarSpanDrawing(anchors: anchors, proxy: proxy)
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
