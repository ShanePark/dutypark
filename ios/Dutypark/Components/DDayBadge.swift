import SwiftUI

struct DDayBadge: View {
    let daysLeft: Int

    var body: some View {
        Text(displayText)
            .font(.system(size: 12, weight: .bold))
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(badgeGradient)
            .cornerRadius(12)
    }

    private var displayText: String {
        if daysLeft == 0 {
            return "D-Day"
        } else if daysLeft > 0 {
            return "D-\(daysLeft)"
        } else {
            return "D+\(abs(daysLeft))"
        }
    }

    private var badgeGradient: LinearGradient {
        let colors: [Color]
        if daysLeft == 0 {
            colors = [.red, Color(red: 0.86, green: 0.15, blue: 0.15)]
        } else if daysLeft < 0 {
            colors = [.gray, Color(white: 0.4)]
        } else if daysLeft <= 3 {
            colors = [.red, Color(red: 0.86, green: 0.15, blue: 0.15)]
        } else if daysLeft <= 7 {
            colors = [.orange, Color(red: 0.92, green: 0.35, blue: 0.05)]
        } else {
            colors = [Color(white: 0.4), Color(white: 0.3)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }
}

#Preview {
    VStack(spacing: 12) {
        DDayBadge(daysLeft: 0)
        DDayBadge(daysLeft: 1)
        DDayBadge(daysLeft: 3)
        DDayBadge(daysLeft: 7)
        DDayBadge(daysLeft: 30)
        DDayBadge(daysLeft: -5)
    }
}
