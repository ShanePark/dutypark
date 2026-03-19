package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import java.util.*

data class FriendRequestSentEvent(
    val requestId: Long,
    val fromMemberId: Long,
    val toMemberId: Long
)

data class FriendRequestAcceptedEvent(
    val requestId: Long,
    val fromMemberId: Long,
    val toMemberId: Long
)

data class FamilyRequestSentEvent(
    val requestId: Long,
    val fromMemberId: Long,
    val toMemberId: Long
)

data class FamilyRequestAcceptedEvent(
    val requestId: Long,
    val fromMemberId: Long,
    val toMemberId: Long
)

data class ScheduleTaggedEvent(
    val scheduleId: UUID,
    val ownerId: Long,
    val taggedMemberId: Long,
    val scheduleTitle: String
)

data class TodoTaggedEvent(
    val todoId: UUID,
    val ownerId: Long,
    val taggedMemberId: Long,
    val todoTitle: String
)

data class TodoStatusChangedEvent(
    val todoId: UUID,
    val actorId: Long,
    val recipientMemberId: Long,
    val todoTitle: String,
    val newStatus: TodoStatus
)
