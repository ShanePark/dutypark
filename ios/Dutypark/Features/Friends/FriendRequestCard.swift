import SwiftUI

struct FriendRequestCard: View {
    let request: DashboardFriendRequestDto
    let isReceived: Bool
    let onAccept: () -> Void
    let onReject: () -> Void
    let onCancel: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            let member = isReceived ? request.fromMember : request.toMember

            ProfileAvatar(
                memberId: member.id,
                name: member.name,
                hasProfilePhoto: member.hasProfilePhoto ?? false,
                profilePhotoVersion: member.profilePhotoVersion,
                size: 44
            )

            VStack(alignment: .leading, spacing: 2) {
                Text(member.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                if let team = member.team {
                    Text(team)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                if request.requestType == "FAMILY_REQUEST" {
                    Label("가족 요청", systemImage: "house")
                        .font(.caption2)
                        .foregroundColor(.purple)
                }
            }

            Spacer()

            if isReceived {
                HStack(spacing: 8) {
                    Button(action: onReject) {
                        Image(systemName: "xmark")
                            .foregroundColor(.red)
                            .padding(8)
                            .background(Color.red.opacity(0.1))
                            .cornerRadius(8)
                    }

                    Button(action: onAccept) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.green)
                            .padding(8)
                            .background(Color.green.opacity(0.1))
                            .cornerRadius(8)
                    }
                }
            } else {
                Button(action: onCancel) {
                    Text("취소")
                        .font(.caption)
                        .foregroundColor(.orange)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                }
            }
        }
        .padding()
        .background(isReceived ? Color.blue.opacity(0.05) : Color.orange.opacity(0.05))
        .cornerRadius(12)
    }
}

#Preview {
    VStack(spacing: 16) {
        FriendRequestCard(
            request: DashboardFriendRequestDto(
                id: 1,
                fromMember: DashboardFriendDto(
                    id: 1,
                    name: "홍길동",
                    teamId: 1,
                    team: "개발팀",
                    hasProfilePhoto: false,
                    profilePhotoVersion: nil
                ),
                toMember: DashboardFriendDto(
                    id: 2,
                    name: "김철수",
                    teamId: 2,
                    team: "디자인팀",
                    hasProfilePhoto: false,
                    profilePhotoVersion: nil
                ),
                status: "PENDING",
                createdAt: nil,
                requestType: "FRIEND_REQUEST"
            ),
            isReceived: true,
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onCancel: { print("Cancel") }
        )

        FriendRequestCard(
            request: DashboardFriendRequestDto(
                id: 2,
                fromMember: DashboardFriendDto(
                    id: 2,
                    name: "김철수",
                    teamId: 2,
                    team: "디자인팀",
                    hasProfilePhoto: false,
                    profilePhotoVersion: nil
                ),
                toMember: DashboardFriendDto(
                    id: 3,
                    name: "이영희",
                    teamId: nil,
                    team: nil,
                    hasProfilePhoto: false,
                    profilePhotoVersion: nil
                ),
                status: "PENDING",
                createdAt: nil,
                requestType: "FAMILY_REQUEST"
            ),
            isReceived: false,
            onAccept: { print("Accept") },
            onReject: { print("Reject") },
            onCancel: { print("Cancel") }
        )
    }
    .padding()
}
