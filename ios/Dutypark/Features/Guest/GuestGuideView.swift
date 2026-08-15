import SwiftUI

struct GuestGuideView: View {
    @State private var section: Section = .guide

    var body: some View {
        VStack(spacing: 0) {
            Picker("", selection: $section) {
                Text(GuestLocalization.text("guest.guide.title"))
                    .tag(Section.guide)
                Text(SettingsLocalization.string("settings.releaseNotes"))
                    .tag(Section.releaseNotes)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, DPSpacing.medium)
            .padding(.vertical, DPSpacing.small)
            .accessibilityIdentifier("guest.guide.sectionPicker")

            switch section {
            case .guide:
                PublicGuideView(fallbackTitle: GuestLocalization.text("guest.guide.title"))
            case .releaseNotes:
                PublicReleaseNotesView()
            }
        }
    }

    private enum Section: Hashable {
        case guide
        case releaseNotes
    }
}
