package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.service.WebPushService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.whenever
import java.util.Optional
import java.util.UUID

class NotificationEventListenerTest {

    private val notificationService: NotificationService = mock()
    private val notificationRepository: NotificationRepository = mock()
    private val memberRepository: MemberRepository = mock()
    private val webPushService: WebPushService = mock()

    private val listener = NotificationEventListener(
        notificationService = notificationService,
        notificationRepository = notificationRepository,
        memberRepository = memberRepository,
        webPushService = webPushService
    )

    @Test
    fun `handleFriendRequestSent sends push with actor name`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "actor")
        val requestId = 10L
        val notification = notificationWith(
            member = member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = requestId.toString(),
            actorId = actor.id
        )

        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FRIEND_REQUEST_RECEIVED,
                actor.id,
                NotificationReferenceType.FRIEND_REQUEST,
                requestId.toString(),
                null
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(3)
        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))

        listener.handleFriendRequestSent(FriendRequestSentEvent(requestId, actor.id!!, member.id!!))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.FRIEND_REQUEST_RECEIVED,
            actor.id,
            NotificationReferenceType.FRIEND_REQUEST,
            requestId.toString(),
            null
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(
            eq(member.id!!),
            payloadCaptor.capture()
        )
        val payload = payloadCaptor.firstValue
        assertThat(payload.title).isEqualTo("actor")
        assertThat(payload.url).isEqualTo("/friends")
        assertThat(payload.unreadCount).isEqualTo(3)
    }

    @Test
    fun `handleScheduleTagged uses schedule url and null actor name when missing`() {
        val member = memberWithId(1L, "receiver")
        val scheduleId = UUID.randomUUID()
        val notification = notificationWith(
            member = member,
            type = NotificationType.SCHEDULE_TAGGED,
            referenceType = NotificationReferenceType.SCHEDULE,
            referenceId = scheduleId.toString(),
            actorId = 2L,
            content = "meeting"
        )

        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.SCHEDULE_TAGGED,
                2L,
                NotificationReferenceType.SCHEDULE,
                scheduleId.toString(),
                "meeting"
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(0)
        whenever(memberRepository.findById(2L)).thenReturn(Optional.empty())

        listener.handleScheduleTagged(ScheduleTaggedEvent(scheduleId, 2L, member.id!!, "meeting"))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.SCHEDULE_TAGGED,
            2L,
            NotificationReferenceType.SCHEDULE,
            scheduleId.toString(),
            "meeting"
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        val payload = payloadCaptor.firstValue
        assertThat(payload.title).isNull()
        assertThat(payload.url).isEqualTo("/duty/${member.id}")
    }

    @Test
    fun `handleFamilyRequestAccepted uses friends url`() {
        val member = memberWithId(1L, "receiver")
        val requestId = 99L
        val notification = notificationWith(
            member = member,
            type = NotificationType.FAMILY_REQUEST_ACCEPTED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = null,
            actorId = 2L
        )

        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FAMILY_REQUEST_ACCEPTED,
                2L,
                NotificationReferenceType.FRIEND_REQUEST,
                null,
                null
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        listener.handleFamilyRequestAccepted(FamilyRequestAcceptedEvent(requestId, member.id!!, 2L))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.FAMILY_REQUEST_ACCEPTED,
            2L,
            NotificationReferenceType.FRIEND_REQUEST,
            null,
            null
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        val payload = payloadCaptor.firstValue
        assertThat(payload.url).isEqualTo("/friends")
    }

    @Test
    fun `handleFriendRequestAccepted ignores create errors`() {
        doThrow(IllegalStateException("fail")).whenever(notificationService)
            .createNotification(any(), any(), anyOrNull(), anyOrNull(), anyOrNull(), anyOrNull())

        assertDoesNotThrow {
            listener.handleFriendRequestAccepted(FriendRequestAcceptedEvent(1L, 2L, 3L))
        }

        verifyNoInteractions(webPushService)
    }

    @Test
    fun `handleFamilyRequestSent uses friends url`() {
        val member = memberWithId(1L, "receiver")
        val requestId = 10L
        val notification = notificationWith(
            member = member,
            type = NotificationType.FAMILY_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = requestId.toString(),
            actorId = 2L
        )

        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FAMILY_REQUEST_RECEIVED,
                2L,
                NotificationReferenceType.FRIEND_REQUEST,
                requestId.toString(),
                null
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        listener.handleFamilyRequestSent(FamilyRequestSentEvent(requestId, 2L, member.id!!))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.FAMILY_REQUEST_RECEIVED,
            2L,
            NotificationReferenceType.FRIEND_REQUEST,
            requestId.toString(),
            null
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        val payload = payloadCaptor.firstValue
        assertThat(payload.url).isEqualTo("/friends")
    }

    private fun notificationWith(
        member: Member,
        type: NotificationType,
        referenceType: NotificationReferenceType?,
        referenceId: String?,
        actorId: Long?,
        content: String? = null
    ): Notification {
        return Notification(
            member = member,
            type = type,
            title = "title",
            content = content,
            referenceType = referenceType,
            referenceId = referenceId,
            actorId = actorId
        )
    }

    private fun memberWithId(id: Long, name: String): Member {
        val member = Member(name, "$name@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }
}
