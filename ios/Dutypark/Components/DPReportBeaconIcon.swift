import SwiftUI

/// The beacon every "report" control in the app raises.
///
/// A menu row paints its icon with the app's tint — blue — even where the row itself
/// is destructive red, so a plain `Image(systemName:)` would leave a blue siren beside
/// red words. An image carrying its own colour is left alone, so the glyph is built
/// pre-tinted and the siren reads as the alarm the wording promises.
struct DPReportBeaconIcon: View {
    static let systemImage = "light.beacon.max"

    var body: some View {
        if let beacon = UIImage(systemName: Self.systemImage)?
            .withTintColor(UIColor(DPColor.danger), renderingMode: .alwaysOriginal) {
            Image(uiImage: beacon)
        } else {
            Image(systemName: Self.systemImage)
        }
    }
}
