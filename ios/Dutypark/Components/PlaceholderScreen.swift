import SwiftUI

struct PlaceholderScreen: View {
    let tab: AppTab

    var body: some View {
        ContentUnavailableView {
            Label {
                Text(tab.navigationTitle)
            } icon: {
                Image(systemName: tab.systemImage)
            }
        } description: {
            Text("placeholder.description")
        }
        .accessibilityIdentifier("screen.\(tab.rawValue)")
    }
}
