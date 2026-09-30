import CoreText
import UIKit
import XCTest
@testable import Dutypark

final class WidgetCalendarFontTests: XCTestCase {
    @MainActor
    func testEmbeddedWidgetRegistersTheSameCalendarFontsAsTheApp() throws {
        let widgetURL = Bundle.main.bundleURL
            .appendingPathComponent("PlugIns/DutyparkWidgets.appex", isDirectory: true)
        let widget = try XCTUnwrap(Bundle(url: widgetURL))
        let appFonts = try XCTUnwrap(Bundle.main.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        let widgetFonts = try XCTUnwrap(widget.object(forInfoDictionaryKey: "UIAppFonts") as? [String])
        XCTAssertEqual(Set(widgetFonts), Set(appFonts))

        for (file, postScriptName) in [
            ("Maplestory OTF Light", DPFont.lightPostScriptName),
            ("Maplestory OTF Bold", DPFont.boldPostScriptName)
        ] {
            let appURL = try XCTUnwrap(Bundle.main.url(forResource: file, withExtension: "otf"))
            let fontURL = try XCTUnwrap(widget.url(forResource: file, withExtension: "otf"))
            XCTAssertEqual(try Data(contentsOf: fontURL), try Data(contentsOf: appURL))
            let descriptors = try XCTUnwrap(
                CTFontManagerCreateFontDescriptorsFromURL(fontURL as CFURL) as? [CTFontDescriptor]
            )
            let descriptor = try XCTUnwrap(descriptors.first)
            let font = CTFontCreateWithFontDescriptor(descriptor, 12, nil)
            XCTAssertEqual(CTFontCopyPostScriptName(font) as String, postScriptName)
            let appFont = try XCTUnwrap(UIFont(name: postScriptName, size: 12))
            XCTAssertEqual(CTFontCopyFamilyName(font) as String, appFont.familyName)
            XCTAssertLessThanOrEqual(
                CTFontGetAscent(font) + CTFontGetDescent(font) + CTFontGetLeading(font),
                15,
                "The 12pt calendar font must fit the widget's existing date/duty slot."
            )
            let holidayFont = CTFontCreateWithFontDescriptor(descriptor, 9, nil)
            XCTAssertLessThanOrEqual(
                CTFontGetAscent(holidayFont) + CTFontGetDescent(holidayFont) + CTFontGetLeading(holidayFont),
                11,
                "The 9pt holiday font must fit the widget's existing holiday slot."
            )

            for character in "월화수목금토일주야비휴추석1234567890" {
                let text = String(character) as CFString
                let shapedFont = CTFontCreateForString(font, text, CFRange(location: 0, length: 1))
                XCTAssertEqual(CTFontCopyPostScriptName(shapedFont) as String, postScriptName)
            }
        }
    }
}
