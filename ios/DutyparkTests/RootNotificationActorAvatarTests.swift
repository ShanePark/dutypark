import Foundation
import Testing
@testable import Dutypark

struct RootNotificationActorAvatarTests {
    @Test
    func photoRequestUsesActorIDThumbnailAndVersion() throws {
        let notification = try notification(
            actorID: 42,
            hasProfilePhoto: true,
            profilePhotoVersion: 7
        )

        let request = try #require(NotificationDropdownActorPhotoRequest(notification: notification))

        #expect(request.path == "members/42/profile-photo")
        #expect(request.queryItems == [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: "7"),
        ])
        #expect(request.cacheIdentity == "42-7")
    }

    @Test
    func photoRequestStillUsesActorIDWhenPhotoMetadataIsStale() throws {
        let notification = try notification(
            actorID: 42,
            hasProfilePhoto: false,
            profilePhotoVersion: 7
        )

        let request = try #require(NotificationDropdownActorPhotoRequest(notification: notification))

        #expect(request.path == "members/42/profile-photo")
        #expect(request.queryItems == [
            URLQueryItem(name: "thumbnail", value: "true"),
            URLQueryItem(name: "v", value: "7"),
        ])
    }

    @Test
    func photoRequestIsAbsentWithoutActorID() throws {
        let notification = try notification(
            actorID: nil,
            hasProfilePhoto: true,
            profilePhotoVersion: 7
        )

        #expect(NotificationDropdownActorPhotoRequest(notification: notification) == nil)
    }

    private func notification(
        actorID: Int64?,
        hasProfilePhoto: Bool,
        profilePhotoVersion: Int64
    ) throws -> NotificationDTO {
        let actorIDValue = actorID.map(String.init) ?? "null"
        let json = #"""
        {
          "id": "00000000-0000-0000-0000-000000000901",
          "type": "FRIEND_REQUEST_RECEIVED",
          "referenceType": "FRIEND_REQUEST",
          "referenceId": "901",
          "actorId": \#(actorIDValue),
          "payload": {
            "version": 1,
            "actor": {
              "name": "민지",
              "hasProfilePhoto": \#(hasProfilePhoto),
              "profilePhotoVersion": \#(profilePhotoVersion)
            }
          },
          "isRead": false,
          "createdAt": "2026-08-15T08:30:00"
        }
        """#

        return try JSONDecoder().decode(NotificationDTO.self, from: Data(json.utf8))
    }
}
