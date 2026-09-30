import SwiftUI
import UIKit
import XCTest
@testable import Dutypark

final class DutyTypeColorPaletteTests: XCTestCase {
    func testPaletteAndDefaultMatchTheSharedContract() {
        XCTAssertEqual(DutyTypeColorPalette.options.map(\.hex), [
            "#ECC2C9", "#F6BC7A", "#F6D365", "#D8BF9B", "#C8DD70", "#A6D99B",
            "#8FDCBD", "#9DDBDE", "#D1B8EC", "#E9AEE9", "#CCC8BD"
        ])
        XCTAssertEqual(TeamManageModalLogic.defaultDutyTypeColor, "#F6D365")
        XCTAssertEqual(DutyTypeColorPalette.initialColor(existing: "#aBc123"), "#aBc123")
        XCTAssertEqual(DutyTypeColorPalette.initialColor(existing: nil), "#F6D365")
    }

    func testCustomSelectionAllowsAnyHexAndOnlyEmitsFeedbackForAnActualChange() {
        XCTAssertFalse(DutyTypeColorPalette.shouldSelect("#f6d365", current: "#F6D365"))
        XCTAssertTrue(DutyTypeColorPalette.shouldSelect("#000000", current: "#aBc123"))
        XCTAssertTrue(DutyTypeColorPalette.shouldSelect("#FFFFFF", current: "#aBc123"))
        XCTAssertTrue(DutyTypeColorPalette.shouldSelect("#123456", current: "#aBc123"))
        XCTAssertFalse(DutyTypeColorPalette.shouldSelect("#ABC123", current: "#aBc123"))
        XCTAssertFalse(DutyTypeColorPalette.shouldSelect("#123", current: "#aBc123"))
        XCTAssertFalse(DutyTypeColorPalette.shouldSelect("123456", current: "#aBc123"))
        XCTAssertFalse(DutyTypeColorPalette.shouldSelect("#GG1122", current: "#aBc123"))
        XCTAssertTrue(DutyTypeColorPalette.shouldSelect("#8FDCBD", current: "#aBc123"))
        XCTAssertFalse(DutyTypeColorPalette.contains("#aBc123"))
        XCTAssertTrue(DutyTypeColorPalette.contains("#8fdcbd"))
        for legacy in ["#F2C094", "#ADD1AF", "#A8D8C2", "#D3BCE2"] {
            XCTAssertFalse(DutyTypeColorPalette.contains(legacy))
            XCTAssertEqual(DutyTypeColorPalette.initialColor(existing: legacy), legacy)
        }
    }

    func testPaletteWeekdayAndDutyTextMeetContrastWithoutChangingLegacyColors() throws {
        for option in DutyTypeColorPalette.options {
            for foreground in ["#991B1B", "#1E40AF", "#1F2937"] {
                XCTAssertGreaterThanOrEqual(try contrast(option.hex, foreground), 4.5, option.hex)
            }
            XCTAssertFalse(DPCalendarCellStyle.usesLightForeground(on: option.hex))
        }
        XCTAssertEqual(DPCalendarCellStyle.dayNumberColor(dutyColor: "#ABC123", weekdayIndex: 0, hasHoliday: false), DPColor.dangerHover)
        XCTAssertEqual(DPCalendarCellStyle.dayNumberColor(dutyColor: nil, weekdayIndex: 6, hasHoliday: false), DPColor.accentHover)
        XCTAssertEqual(DPCalendarCellStyle.dayNumberColor(dutyColor: "#F6D365", weekdayIndex: 0, hasHoliday: false), DutyTypeColorPalette.sundayColor)
        XCTAssertEqual(DPCalendarCellStyle.dayNumberColor(dutyColor: "#8FDCBD", weekdayIndex: 6, hasHoliday: false), DutyTypeColorPalette.saturdayColor)
        XCTAssertEqual(DPCalendarCellStyle.holidayForeground(dutyColor: "#ABC123"), DPColor.dangerHover)
        XCTAssertEqual(DPCalendarCellStyle.holidayForeground(dutyColor: nil), DPColor.dangerHover)
        for option in DutyTypeColorPalette.options {
            XCTAssertEqual(DPCalendarCellStyle.holidayForeground(dutyColor: option.hex), DutyTypeColorPalette.sundayColor)
            XCTAssertEqual(DPCalendarCellStyle.dayNumberColor(dutyColor: option.hex, weekdayIndex: 2, hasHoliday: true), DutyTypeColorPalette.sundayColor)
        }
    }

    private func contrast(_ first: String, _ second: String) throws -> Double {
        func luminance(_ hex: String) throws -> Double {
            let rgb = try XCTUnwrap(DPCalendarCellStyle.rgb(hex))
            let components = [rgb.red, rgb.green, rgb.blue].map { value -> Double in
                let channel = Double(value) / 255
                return channel <= 0.04045 ? channel / 12.92 : pow((channel + 0.055) / 1.055, 2.4)
            }
            return components[0] * 0.2126 + components[1] * 0.7152 + components[2] * 0.0722
        }
        let a = try luminance(first)
        let b = try luminance(second)
        return (max(a, b) + 0.05) / (min(a, b) + 0.05)
    }

    @MainActor
    func testRenderedPickerAndCalendarPaletteInLightAndDarkAtPhoneWidths() throws {
        for width: CGFloat in [375, 390] {
            for scheme in [ColorScheme.light, .dark] {
                let theme = scheme == .dark ? "dark" : "light"
                let root = DutyPaletteRenderFixture()
                    .preferredColorScheme(scheme)
                    .environment(\.locale, Locale(identifier: "ko"))
                let host = UIHostingController(rootView: root)
                host.view.frame = CGRect(x: 0, y: 0, width: width, height: 2_200)
                let window = UIWindow(frame: host.view.frame)
                window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
                window.rootViewController = host
                window.makeKeyAndVisible()
                defer { window.isHidden = true }
                host.view.setNeedsLayout()
                host.view.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.05))
                host.view.layoutIfNeeded()

                let image = UIGraphicsImageRenderer(size: host.view.bounds.size).image { context in
                    host.view.layer.render(in: context.cgContext)
                }
                XCTAssertEqual(image.size.width, width)
                XCTAssertEqual(image.size.height, 2_200)
                let attachment = XCTAttachment(image: image)
                let attachmentName = "duty-palette-\(Int(width))pt-\(theme)"
                attachment.name = attachmentName
                attachment.lifetime = .keepAlways
                XCTContext.runActivity(named: attachmentName) { $0.add(attachment) }
                let url = URL(fileURLWithPath: NSTemporaryDirectory())
                    .appending(path: "dutypark-palette-\(Int(width))pt-\(theme).png")
                try XCTUnwrap(image.pngData()).write(to: url)
                print("DUTYPARK_PALETTE_RENDER: \(url.path)")
            }
        }
    }

    @MainActor
    func testRenderedEditorKeepsPaletteInScrollablePanelAtPhoneWidths() throws {
        for width: CGFloat in [375, 390] {
            for scheme in [ColorScheme.light, .dark] {
                let theme = scheme == .dark ? "dark" : "light"
                let viewModel = TeamManageViewModel(teamID: 7)
                let root = ZStack {
                    DPColor.backgroundPrimary
                    TeamDutyTypeEditor(
                        viewModel: viewModel,
                        maximumHeight: 812,
                        interaction: .constant(TeamModalInteractionState()),
                        dismissAfterSuccess: {},
                        dismiss: {}
                    )
                    .padding(.horizontal, 12)
                }
                .preferredColorScheme(scheme)
                .environment(\.locale, Locale(identifier: "ko"))
                let host = UIHostingController(rootView: root)
                host.view.frame = CGRect(x: 0, y: 0, width: width, height: 812)
                let window = UIWindow(frame: host.view.frame)
                window.overrideUserInterfaceStyle = scheme == .dark ? .dark : .light
                window.rootViewController = host
                window.makeKeyAndVisible()
                defer { window.isHidden = true }
                host.view.layoutIfNeeded()
                RunLoop.main.run(until: Date(timeIntervalSinceNow: 0.1))
                host.view.layoutIfNeeded()

                func scrollViews(in view: UIView) -> [UIScrollView] {
                    (view as? UIScrollView).map { [$0] } ?? view.subviews.flatMap { scrollViews(in: $0) }
                }
                let scrollView = try XCTUnwrap(scrollViews(in: host.view).first)
                let viewport = scrollView.convert(scrollView.bounds, to: host.view)
                XCTAssertGreaterThan(viewport.height, 0)
                XCTAssertGreaterThanOrEqual(viewport.minY, 0)
                XCTAssertLessThanOrEqual(viewport.maxY, host.view.bounds.maxY)
                XCTAssertLessThanOrEqual(viewport.width, width)
                let bottomOffset = max(0, scrollView.contentSize.height - scrollView.bounds.height)
                scrollView.setContentOffset(CGPoint(x: 0, y: bottomOffset), animated: false)
                host.view.layoutIfNeeded()

                let image = UIGraphicsImageRenderer(size: host.view.bounds.size).image { context in
                    host.view.layer.render(in: context.cgContext)
                }
                let name = "duty-editor-\(Int(width))pt-\(theme)"
                let attachment = XCTAttachment(image: image)
                attachment.name = name
                attachment.lifetime = .keepAlways
                XCTContext.runActivity(named: name) { $0.add(attachment) }
                let url = URL(fileURLWithPath: NSTemporaryDirectory()).appending(path: "dutypark-\(name).png")
                try XCTUnwrap(image.pngData()).write(to: url)
                print("DUTYPARK_PALETTE_EDITOR_RENDER: \(url.path)")
            }
        }
    }
}

private struct DutyPaletteRenderFixture: View {
    var body: some View {
        VStack(alignment: .leading, spacing: DPSpacing.small) {
            DPDutyTypeColorPicker(selection: .constant(DutyTypeColorPalette.defaultColor))
            DPDutyTypeColorPicker(selection: .constant("#ABC123"))
            HStack(spacing: 0) {
                ForEach(0..<7) { index in
                    DPCalendarWeekdayHeaderCell(label: ["일", "월", "화", "수", "목", "금", "토"][index], weekdayIndex: index)
                }
            }
            ForEach(DutyTypeColorPalette.options) { option in
                VStack(spacing: 0) {
                    TeamDutyTypeBadge(name: "주간 근무", color: option.hex, memberCount: nil)
                    HStack(spacing: 0) {
                        ForEach(0..<7) { weekday in
                            VStack(spacing: DPSpacing.small) {
                                DPCalendarDayNumber(day: 20 + weekday, weekdayIndex: weekday, dutyColor: option.hex, hasHoliday: weekday == 2)
                                Text("주")
                                    .font(DPTypography.bodyMedium)
                                    .foregroundStyle(DPCalendarCellStyle.primaryForeground(dutyColor: option.hex))
                                if weekday == 2 {
                                    Text("공휴일")
                                        .font(DPFont.light(size: 9, relativeTo: .caption2))
                                        .foregroundStyle(DPCalendarCellStyle.holidayForeground(dutyColor: option.hex))
                                        .lineLimit(1)
                                }
                            }
                            .frame(maxWidth: .infinity, minHeight: 54)
                            .background(DPCalendarCellStyle.cellBackground(dutyColor: option.hex, isCurrentMonth: true))
                            .overlay { Rectangle().stroke(DPCalendarCellStyle.cellBorder(dutyColor: option.hex), lineWidth: 0.5) }
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(DPSpacing.compact)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DPColor.backgroundModal)
    }
}
