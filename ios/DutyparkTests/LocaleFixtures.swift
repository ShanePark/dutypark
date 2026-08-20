import Foundation

/// The app follows the system language, so copy is asserted per language through the
/// explicit-locale seam instead of a runtime override.
extension Locale {
    static let korean = Locale(identifier: "ko")
    static let english = Locale(identifier: "en")
}
