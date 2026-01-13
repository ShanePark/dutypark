import SwiftUI

struct DDayCard: View {
    let dday: DDayDto
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 16) {
            // D-Day badge
            DDayBadge(daysLeft: dday.daysLeft)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(dday.title)
                        .font(.headline)

                    if dday.isPrivate {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Text(formatDate(dday.date))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
                    .padding(8)
                    .background(Color.red.opacity(0.1))
                    .cornerRadius(8)
            }
        }
        .padding()
        .background(cardBackground)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    @ViewBuilder
    private var cardBackground: some View {
        if dday.daysLeft == 0 {
            LinearGradient(
                colors: [Color.red.opacity(0.1), Color.orange.opacity(0.1)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        } else if dday.daysLeft > 0 {
            Color(.systemBackground)
        } else {
            Color(.systemGray6)
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let inputFormatter = DateFormatter()
        inputFormatter.dateFormat = "yyyy-MM-dd"

        guard let date = inputFormatter.date(from: dateString) else {
            return dateString
        }

        let outputFormatter = DateFormatter()
        outputFormatter.locale = Locale(identifier: "ko_KR")
        outputFormatter.dateFormat = "yyyy년 M월 d일 (E)"

        return outputFormatter.string(from: date)
    }
}

#Preview {
    VStack(spacing: 12) {
        DDayCard(
            dday: DDayDto(id: 1, title: "생일", date: "2025-06-15", isPrivate: false, calc: 0, daysLeft: 0),
            onDelete: {}
        )
        DDayCard(
            dday: DDayDto(id: 2, title: "기념일", date: "2025-06-20", isPrivate: true, calc: 5, daysLeft: 5),
            onDelete: {}
        )
        DDayCard(
            dday: DDayDto(id: 3, title: "지난 이벤트", date: "2025-06-01", isPrivate: false, calc: -10, daysLeft: -10),
            onDelete: {}
        )
    }
    .padding()
}
