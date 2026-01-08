package com.tistory.shanepark.dutypark.notification.event

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
    val taggedMemberId: Long
)
