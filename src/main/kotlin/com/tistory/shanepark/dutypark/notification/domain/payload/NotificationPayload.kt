package com.tistory.shanepark.dutypark.notification.domain.payload

sealed interface NotificationPayload {
    val version: Int
}

sealed interface ActorNotificationPayload : NotificationPayload {
    val actor: NotificationActorSnapshot
}

data class NotificationActorSnapshot(
    val name: String?,
    val hasProfilePhoto: Boolean,
    val profilePhotoVersion: Long,
)

data class FriendRequestReceivedPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
) : ActorNotificationPayload

data class FriendRequestAcceptedPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
) : ActorNotificationPayload

data class FamilyRequestReceivedPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
) : ActorNotificationPayload

data class FamilyRequestAcceptedPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
) : ActorNotificationPayload

data class ScheduleTaggedPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
    val scheduleTitle: String,
) : ActorNotificationPayload

data class TodoTaggedPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
    val todoTitle: String,
) : ActorNotificationPayload

data class TodoStatusTodoPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
    val todoTitle: String,
) : ActorNotificationPayload

data class TodoStatusInProgressPayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
    val todoTitle: String,
) : ActorNotificationPayload

data class TodoStatusDonePayload(
    override val version: Int = 1,
    override val actor: NotificationActorSnapshot,
    val todoTitle: String,
) : ActorNotificationPayload
