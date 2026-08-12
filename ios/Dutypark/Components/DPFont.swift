import SwiftUI

enum DPFont {
    static let lightPostScriptName = "MaplestoryOTFLight"
    static let boldPostScriptName = "MaplestoryOTFBold"

    static func light(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(lightPostScriptName, size: size, relativeTo: textStyle)
    }

    static func bold(
        size: CGFloat,
        relativeTo textStyle: Font.TextStyle
    ) -> Font {
        .custom(boldPostScriptName, size: size, relativeTo: textStyle)
    }
}
