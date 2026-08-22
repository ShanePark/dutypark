import Foundation
import Testing
@testable import Dutypark

struct DPProfileAvatarTests {
    @Test("profile avatars share the generated fallback asset and request the member photo URL")
    func presentationUsesSharedAssetAndMemberPhotoURL() throws {
        #expect(DPProfileAvatarPresentation.defaultAssetName == "DefaultProfile")

        let url = try #require(
            DPProfileAvatarPresentation.profilePhotoURL(memberID: 42, version: 7)
        )

        #expect(url.path.hasSuffix("/members/42/profile-photo"))
        #expect(URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems == [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: "7"),
        ])
        #expect(DPProfileAvatarPresentation.profilePhotoURL(memberID: nil, version: 7) == nil)
    }
}
