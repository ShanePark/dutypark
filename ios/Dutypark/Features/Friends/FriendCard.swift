import SwiftUI

struct FriendCard: View {
    let friend: Friend

    var body: some View {
        HStack(spacing: 12) {
            ProfileAvatar(
                memberId: friend.id,
                name: friend.name,
                hasProfilePhoto: friend.hasProfilePhoto ?? false,
                profilePhotoVersion: friend.profilePhotoVersion,
                size: 48
            )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(friend.name)
                        .font(.headline)

                    if friend.isFamily {
                        Image(systemName: "house.fill")
                            .font(.caption)
                            .foregroundColor(.purple)
                    }

                    if friend.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }

                if let team = friend.team {
                    Text(team)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(friend.isPinned ? Color.orange.opacity(0.05) : Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

#Preview {
    VStack(spacing: 16) {
        FriendCard(
            friend: Friend(
                id: 1,
                name: "홍길동",
                team: "개발팀",
                isFamily: false,
                isPinned: false,
                hasProfilePhoto: false,
                profilePhotoVersion: nil
            )
        )

        FriendCard(
            friend: Friend(
                id: 2,
                name: "김철수",
                team: "디자인팀",
                isFamily: true,
                isPinned: true,
                hasProfilePhoto: false,
                profilePhotoVersion: nil
            )
        )
    }
    .padding()
}
