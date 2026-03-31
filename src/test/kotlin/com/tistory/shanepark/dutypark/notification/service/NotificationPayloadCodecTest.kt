package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import tools.jackson.module.kotlin.jacksonMapperBuilder

class NotificationPayloadCodecTest {
    private val codec = NotificationPayloadCodec(jacksonMapperBuilder().build())

    @Test
    fun `round-trips friend request payload`() {
        val payload = FriendRequestReceivedPayload(
            actor = NotificationActorSnapshot(
                name = "Shane",
                hasProfilePhoto = true,
                profilePhotoVersion = 3,
            ),
        )

        val json = codec.serialize(payload)
        val decoded = codec.deserialize(NotificationType.FRIEND_REQUEST_RECEIVED, payload.version, json)

        assertThat(decoded).isEqualTo(payload)
    }

    @Test
    fun `round-trips schedule tagged payload`() {
        val payload = ScheduleTaggedPayload(
            actor = NotificationActorSnapshot(
                name = "Shane",
                hasProfilePhoto = true,
                profilePhotoVersion = 3,
            ),
            scheduleTitle = "팀 회의",
        )

        val json = codec.serialize(payload)
        val decoded = codec.deserialize(NotificationType.SCHEDULE_TAGGED, payload.version, json)

        assertThat(decoded).isEqualTo(payload)
    }

    @Test
    fun `returns null for blank payload json`() {
        val decoded = codec.deserialize(NotificationType.TODO_TAGGED, null, null)

        assertThat(decoded).isNull()
    }

    @Test
    fun `safeDeserialize returns missing result for blank payload json`() {
        val decoded = codec.safeDeserialize(NotificationType.TODO_TAGGED, null, null)

        assertThat(decoded).isEqualTo(
            NotificationPayloadDecodeResult.Missing("Notification payload JSON is blank")
        )
    }

    @Test
    fun `deserializes json column value when payload is wrapped as a quoted json string`() {
        val payload = FriendRequestReceivedPayload(
            actor = NotificationActorSnapshot(
                name = "Shane",
                hasProfilePhoto = false,
                profilePhotoVersion = 0,
            ),
        )
        val wrappedJson = jacksonMapperBuilder().build().writeValueAsString(codec.serialize(payload))

        val decoded = codec.deserialize(NotificationType.FRIEND_REQUEST_RECEIVED, payload.version, wrappedJson)

        assertThat(decoded).isEqualTo(payload)
    }

    @Test
    fun `falls back to version one when payload version column is null`() {
        val payloadJson = """
            {
              "actor": {
                "name": "Shane",
                "hasProfilePhoto": true,
                "profilePhotoVersion": 3
              }
            }
        """.trimIndent()

        val decoded = codec.deserialize(NotificationType.FRIEND_REQUEST_RECEIVED, null, payloadJson)

        assertThat(decoded).isEqualTo(
            FriendRequestReceivedPayload(
                actor = NotificationActorSnapshot(
                    name = "Shane",
                    hasProfilePhoto = true,
                    profilePhotoVersion = 3,
                ),
            )
        )
    }

    @Test
    fun `reads version from payload json when version column is missing`() {
        val payloadJson = """
            {
              "version": 1,
              "actor": {
                "name": "Shane",
                "hasProfilePhoto": false,
                "profilePhotoVersion": 0
              },
              "scheduleTitle": "팀 회의"
            }
        """.trimIndent()

        val decoded = codec.deserialize(NotificationType.SCHEDULE_TAGGED, null, payloadJson)

        assertThat(decoded).isEqualTo(
            ScheduleTaggedPayload(
                actor = NotificationActorSnapshot(
                    name = "Shane",
                    hasProfilePhoto = false,
                    profilePhotoVersion = 0,
                ),
                scheduleTitle = "팀 회의",
            )
        )
    }

    @Test
    fun `safeDeserialize returns invalid result for unsupported payload version`() {
        val payloadJson = """
            {
              "version": 2,
              "actor": {
                "name": "Shane",
                "hasProfilePhoto": false,
                "profilePhotoVersion": 0
              }
            }
        """.trimIndent()

        val decoded = codec.safeDeserialize(NotificationType.FRIEND_REQUEST_RECEIVED, 2, payloadJson)

        assertThat(decoded).isEqualTo(
            NotificationPayloadDecodeResult.Invalid(
                "Unsupported notification payload version 2 for FRIEND_REQUEST_RECEIVED"
            )
        )
    }

    @Test
    fun `ensureCompatible throws for mismatched payload type`() {
        val payload = ScheduleTaggedPayload(
            actor = NotificationActorSnapshot(
                name = "Shane",
                hasProfilePhoto = false,
                profilePhotoVersion = 0,
            ),
            scheduleTitle = "팀 회의",
        )

        org.junit.jupiter.api.assertThrows<IllegalArgumentException> {
            codec.ensureCompatible(NotificationType.FRIEND_REQUEST_RECEIVED, payload)
        }
    }
}
