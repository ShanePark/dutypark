import Foundation
import Testing
@testable import Dutypark

struct RootNotificationActorAvatarTests {
    @Test
    func photoRequestUsesActorIDThumbnailAndVersion() throws {
        let notification = try makeNotification(
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
    func photoRequestIsAbsentWhenActorHasNoPhoto() throws {
        let notification = try makeNotification(
            actorID: 42,
            hasProfilePhoto: false,
            profilePhotoVersion: 7
        )

        #expect(NotificationDropdownActorPhotoRequest(notification: notification) == nil)

        let unknownMetadata = try makeNotification(
            actorID: 42,
            hasProfilePhoto: nil,
            profilePhotoVersion: 7
        )
        #expect(NotificationDropdownActorPhotoRequest(notification: unknownMetadata) != nil)
    }

    @Test
    func photoRequestIsAbsentWithoutActorID() throws {
        let notification = try makeNotification(
            actorID: nil,
            hasProfilePhoto: true,
            profilePhotoVersion: 7
        )

        #expect(NotificationDropdownActorPhotoRequest(notification: notification) == nil)
    }

    private func makeNotification(
        actorID: Int64?,
        hasProfilePhoto: Bool?,
        profilePhotoVersion: Int64
    ) throws -> NotificationDTO {
        let actorIDValue = actorID.map(String.init) ?? "null"
        let actorValue: String
        if let hasProfilePhoto {
            actorValue = #"{"name":"민지","hasProfilePhoto":\#(hasProfilePhoto),"profilePhotoVersion":\#(profilePhotoVersion)}"#
        } else {
            actorValue = "null"
        }
        let json = #"""
        {
          "id": "00000000-0000-0000-0000-000000000901",
          "type": "FRIEND_REQUEST_RECEIVED",
          "referenceType": "FRIEND_REQUEST",
          "referenceId": "901",
          "actorId": \#(actorIDValue),
          "payload": {
            "version": 1,
            "actor": \#(actorValue)
          },
          "isRead": false,
          "createdAt": "2026-08-15T08:30:00"
        }
        """#

        return try JSONDecoder().decode(NotificationDTO.self, from: Data(json.utf8))
    }
}
