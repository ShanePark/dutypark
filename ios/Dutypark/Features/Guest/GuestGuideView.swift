import SwiftUI

struct GuestGuideView: View {
    @AppStorage(SettingsPreference.languageKey) private var languageCode = ""

    var body: some View {
        DutyparkGuideWebView(destination: .guide, languageCode: languageCode)
            .background(DPColor.backgroundPrimary)
            .navigationTitle(GuestLocalization.text("guest.guide.title"))
            .navigationBarTitleDisplayMode(.inline)
    }

}
