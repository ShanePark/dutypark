import SwiftUI

struct NotificationRow: View {
    let notification: NotificationDto
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 12) {
                // Unread indicator
                Circle()
                    .fill(notification.isRead ? Color.clear : Color.blue)
                    .frame(width: 8, height: 8)
                    .padding(.top, 8)

                // Actor avatar
                ProfileAvatar(
                    memberId: notification.actorId,
                    name: notification.actorName ?? "?",
                    hasProfilePhoto: notification.actorHasProfilePhoto ?? false,
                    profilePhotoVersion: notification.actorProfilePhotoVersion,
                    size: 44
                )

                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text(notification.title)
                            .font(.subheadline)
                            .fontWeight(notification.isRead ? .regular : .semibold)
                            .foregroundColor(.primary)

                        Spacer()

                        Text(formatDate(notification.createdAt))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    if let content = notification.content {
                        Text(content)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    }

                    // Notification type badge
                    notificationTypeBadge
                }
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(notification.isRead ? Color(.systemBackground) : Color.blue.opacity(0.05))
            .cornerRadius(12)
        }
        .buttonStyle(.plain)
    }

    private var notificationTypeBadge: some View {
        HStack(spacing: 4) {
            Image(systemName: notification.type.iconName)
                .font(.caption2)
            Text(notification.type.displayName)
                .font(.caption2)
        }
        .foregroundColor(typeColor)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(typeColor.opacity(0.1))
        .cornerRadius(4)
    }

    private var typeColor: Color {
        switch notification.type {
        case .friendRequestReceived, .friendRequestAccepted:
            return .blue
        case .familyRequestReceived, .familyRequestAccepted:
            return .purple
        case .scheduleTagged:
            return .green
        }
    }

    private func formatDate(_ dateString: String) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        guard let date = formatter.date(from: dateString) else {
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: dateString) else {
                return dateString
            }
            return relativeDate(from: date)
        }
        return relativeDate(from: date)
    }

    private func relativeDate(from date: Date) -> String {
        let now = Date()
        let components = Calendar.current.dateComponents([.minute, .hour, .day], from: date, to: now)

        if let day = components.day, day > 0 {
            return day == 1 ? "어제" : "\(day)일 전"
        } else if let hour = components.hour, hour > 0 {
            return "\(hour)시간 전"
        } else if let minute = components.minute, minute > 0 {
            return "\(minute)분 전"
        } else {
            return "방금"
        }
    }
}

#Preview {
    VStack {
        NotificationRow(
            notification: NotificationDto(
                id: "1",
                type: .friendRequestReceived,
                title: "홍길동님이 친구 요청을 보냈습니다",
                content: nil,
                referenceType: .friendRequest,
                referenceId: "123",
                actorId: 1,
                actorName: "홍길동",
                actorHasProfilePhoto: false,
                actorProfilePhotoVersion: nil,
                isRead: false,
                createdAt: "2025-01-13T10:00:00Z"
            ),
            onTap: {}
        )

        NotificationRow(
            notification: NotificationDto(
                id: "2",
                type: .scheduleTagged,
                title: "김철수님이 일정에 태그했습니다",
                content: "팀 회의",
                referenceType: .schedule,
                referenceId: "456",
                actorId: 2,
                actorName: "김철수",
                actorHasProfilePhoto: true,
                actorProfilePhotoVersion: 1,
                isRead: true,
                createdAt: "2025-01-12T15:30:00Z"
            ),
            onTap: {}
        )
    }
    .padding()
}
