import SwiftUI

struct TeamScheduleCard: View {
    let schedule: TeamScheduleDto
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(schedule.content)
                    .font(.headline)

                Spacer()

                if canDelete {
                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundColor(.red)
                    }
                }
            }

            if !schedule.description.isEmpty {
                Text(schedule.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            HStack {
                Image(systemName: "calendar")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(formatDateRange())
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text(schedule.createMember)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }

    private func formatDateRange() -> String {
        if let totalDays = schedule.totalDays, totalDays > 1 {
            return "\(schedule.month)/\(schedule.dayOfMonth) ~ (\(schedule.daysFromStart ?? 1)/\(totalDays)일)"
        }
        return "\(schedule.month)/\(schedule.dayOfMonth)"
    }
}
