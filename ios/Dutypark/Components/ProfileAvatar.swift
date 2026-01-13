import SwiftUI

struct ProfileAvatar: View {
    let memberId: Int?
    let name: String
    let hasProfilePhoto: Bool
    let profilePhotoVersion: Int?
    let size: CGFloat

    init(memberId: Int? = nil, name: String, hasProfilePhoto: Bool = false, profilePhotoVersion: Int? = nil, size: CGFloat = 40) {
        self.memberId = memberId
        self.name = name
        self.hasProfilePhoto = hasProfilePhoto
        self.profilePhotoVersion = profilePhotoVersion
        self.size = size
    }

    var body: some View {
        if hasProfilePhoto, let memberId = memberId {
            AsyncImage(url: profilePhotoURL(memberId: memberId)) { phase in
                switch phase {
                case .success(let image):
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: size, height: size)
                        .clipShape(Circle())
                case .failure, .empty:
                    initialsView
                @unknown default:
                    initialsView
                }
            }
        } else {
            initialsView
        }
    }

    private func profilePhotoURL(memberId: Int) -> URL? {
        #if DEBUG
        let baseURL = "http://localhost:8080/api"
        #else
        let baseURL = "https://duty.park/api"
        #endif
        return URL(string: "\(baseURL)/members/\(memberId)/profile-photo?thumbnail=true&v=\(profilePhotoVersion ?? 0)")
    }

    private var initialsView: some View {
        Circle()
            .fill(Color.blue.opacity(0.2))
            .frame(width: size, height: size)
            .overlay(
                Text(String(name.prefix(1)))
                    .font(.system(size: size * 0.4, weight: .semibold))
                    .foregroundColor(.blue)
            )
    }
}

#Preview {
    VStack(spacing: 20) {
        ProfileAvatar(name: "홍길동", size: 60)
        ProfileAvatar(memberId: 1, name: "김철수", hasProfilePhoto: false, size: 40)
        ProfileAvatar(memberId: 2, name: "이영희", hasProfilePhoto: true, profilePhotoVersion: 1, size: 80)
    }
}
