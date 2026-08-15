import SwiftUI

struct GuestGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""

    var body: some View {
        DutyparkGuideWebView(
            destination: .guide,
            languageCode: languageCode,
            onNavigateHome: { dismiss() }
        )
            .background(DPColor.backgroundPrimary)
            .navigationTitle(GuestLocalization.text("guest.guide.title"))
            .navigationBarTitleDisplayMode(.inline)
    }

}
