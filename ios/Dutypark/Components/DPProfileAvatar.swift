import SwiftUI

/// The shape used by a profile avatar. Most member surfaces use a circle, while
/// portrait rails use a rounded rectangle to match the card's crop.
nonisolated enum DPProfileAvatarShape: Sendable {
    case circle
    case roundedRectangle(cornerRadius: CGFloat)
}

nonisolated enum DPProfileAvatarPresentation {
    static let defaultAssetName = "DefaultProfile"

    /// The endpoint is public and returns 404 when a member has no photo. Always
    /// constructing it when an ID exists lets a real photo win even if a stale
    /// member payload says `hasProfilePhoto == false`; `AsyncImage` falls back to
    /// the shared asset for a missing photo or a failed request.
    static func profilePhotoURL(memberID: MemberID?, version: Int64) -> URL? {
        guard let memberID else { return nil }
        return AppConfiguration.apiBaseURL
            .appending(path: "members/\(memberID)/profile-photo")
            .appending(queryItems: [
                URLQueryItem(name: "thumbnail", value: "true"),
                URLQueryItem(name: "v", value: String(version)),
            ])
    }
}

/// A profile image with one app-wide fallback. The fallback intentionally does
/// not include a member initial: names remain text next to the avatar, while
/// the generated silhouette keeps every profile surface visually consistent.
struct DPProfileAvatar: View {
    let memberID: MemberID?
    let profilePhotoVersion: Int64
    let size: CGSize
    var shape: DPProfileAvatarShape = .circle

    init(
        memberID: MemberID?,
        profilePhotoVersion: Int64,
        size: CGFloat,
        shape: DPProfileAvatarShape = .circle
    ) {
        self.memberID = memberID
        self.profilePhotoVersion = profilePhotoVersion
        self.size = CGSize(width: size, height: size)
        self.shape = shape
    }

    init(
        memberID: MemberID?,
        profilePhotoVersion: Int64,
        size: CGSize,
        shape: DPProfileAvatarShape = .circle
    ) {
        self.memberID = memberID
        self.profilePhotoVersion = profilePhotoVersion
        self.size = size
        self.shape = shape
    }

    var body: some View {
        switch shape {
        case .circle:
            image
                .frame(width: size.width, height: size.height)
                .background(DPColor.backgroundTertiary)
                .clipShape(Circle())
        case .roundedRectangle(let cornerRadius):
            image
                .frame(width: size.width, height: size.height)
                .background(DPColor.backgroundTertiary)
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
        }
    }

    private var image: some View {
        AsyncImage(
            url: DPProfileAvatarPresentation.profilePhotoURL(
                memberID: memberID,
                version: profilePhotoVersion
            )
        ) { phase in
            if let image = phase.image {
                image
                    .resizable()
                    .scaledToFill()
            } else {
                Image(DPProfileAvatarPresentation.defaultAssetName)
                    .resizable()
                    .scaledToFill()
            }
        }
    }
}
