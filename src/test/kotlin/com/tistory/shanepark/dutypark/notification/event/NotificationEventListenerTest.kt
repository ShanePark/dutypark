package com.tistory.shanepark.dutypark.notification.event

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FamilyRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestAcceptedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusDonePayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusInProgressPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoStatusTodoPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.TodoTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.notification.service.NotificationService
import com.tistory.shanepark.dutypark.push.dto.PushNotificationPayload
import com.tistory.shanepark.dutypark.push.service.WebPushService
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertDoesNotThrow
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.times
import org.mockito.kotlin.verify
import org.mockito.kotlin.verifyNoInteractions
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
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
        webPushService = webPushService,
    )

    @Test
    fun `handleFriendRequestSent builds actor snapshot payload and sends push`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "actor").apply {
            profilePhotoPath = "actor.jpg"
            profilePhotoVersion = 3
        }
        val requestId = 10L
        val payload = FriendRequestReceivedPayload(actor = actorSnapshot(actor))
        val notification = notificationWith(
            member = member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = requestId.toString(),
            actorId = actor.id,
            payload = payload,
        )

        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FRIEND_REQUEST_RECEIVED,
                actor.id,
                NotificationReferenceType.FRIEND_REQUEST,
                requestId.toString(),
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(3)

        listener.handleFriendRequestSent(FriendRequestSentEvent(requestId, actor.id!!, member.id!!))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.FRIEND_REQUEST_RECEIVED,
            actor.id,
            NotificationReferenceType.FRIEND_REQUEST,
            requestId.toString(),
            payload,
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.FRIEND_REQUEST_RECEIVED)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/friends")
        assertThat(payloadCaptor.firstValue.unreadCount).isEqualTo(3)
    }

    @Test
    fun `handleFriendRequestSent keeps generic actor snapshot when actor lookup fails`() {
        val member = memberWithId(1L, "receiver")
        val requestId = 10L
        val payload = FriendRequestReceivedPayload(
            actor = NotificationActorSnapshot(
                name = null,
                hasProfilePhoto = false,
                profilePhotoVersion = 0,
            ),
        )
        val notification = notificationWith(
            member = member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = requestId.toString(),
            actorId = 2L,
            payload = payload,
        )

        whenever(memberRepository.findById(2L)).thenReturn(Optional.empty())
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FRIEND_REQUEST_RECEIVED,
                2L,
                NotificationReferenceType.FRIEND_REQUEST,
                requestId.toString(),
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        listener.handleFriendRequestSent(FriendRequestSentEvent(requestId, 2L, member.id!!))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.FRIEND_REQUEST_RECEIVED,
            2L,
            NotificationReferenceType.FRIEND_REQUEST,
            requestId.toString(),
            payload,
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.FRIEND_REQUEST_RECEIVED)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/friends")
    }

    @Test
    fun `handleScheduleTagged stores schedule title in payload and sends schedule url`() {
        val member = memberWithId(1L, "receiver")
        val scheduleId = UUID.randomUUID()
        val payload = ScheduleTaggedPayload(
            actor = NotificationActorSnapshot(
                name = null,
                hasProfilePhoto = false,
                profilePhotoVersion = 0,
            ),
            scheduleTitle = "meeting",
        )
        val notification = notificationWith(
            member = member,
            type = NotificationType.SCHEDULE_TAGGED,
            referenceType = NotificationReferenceType.SCHEDULE,
            referenceId = scheduleId.toString(),
            actorId = 2L,
            payload = payload,
        )

        whenever(memberRepository.findById(2L)).thenReturn(Optional.empty())
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.SCHEDULE_TAGGED,
                2L,
                NotificationReferenceType.SCHEDULE,
                scheduleId.toString(),
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(0)

        listener.handleScheduleTagged(ScheduleTaggedEvent(scheduleId, 2L, member.id!!, "meeting"))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.SCHEDULE_TAGGED,
            2L,
            NotificationReferenceType.SCHEDULE,
            scheduleId.toString(),
            payload,
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.SCHEDULE_TAGGED)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/duty/${member.id}")
    }

    @Test
    fun `handleTodoTagged uses todo payload and todo url`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "owner")
        val todoId = UUID.randomUUID()
        val payload = TodoTaggedPayload(
            actor = actorSnapshot(actor),
            todoTitle = "보고서 정리",
        )
        val notification = notificationWith(
            member = member,
            type = NotificationType.TODO_TAGGED,
            referenceType = NotificationReferenceType.TODO,
            referenceId = todoId.toString(),
            actorId = actor.id,
            payload = payload,
        )

        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.TODO_TAGGED,
                actor.id,
                NotificationReferenceType.TODO,
                todoId.toString(),
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(2)

        listener.handleTodoTagged(TodoTaggedEvent(todoId, actor.id!!, member.id!!, "보고서 정리"))

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.TODO_TAGGED,
            actor.id,
            NotificationReferenceType.TODO,
            todoId.toString(),
            payload,
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.TODO_TAGGED)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/todo")
        assertThat(payloadCaptor.firstValue.unreadCount).isEqualTo(2)
    }

    @Test
    fun `handleTodoStatusChanged maps status to notification type and payload`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "actor")
        val todoId = UUID.randomUUID()
        val payload = TodoStatusInProgressPayload(
            actor = actorSnapshot(actor),
            todoTitle = "보고서 정리",
        )
        val notification = notificationWith(
            member = member,
            type = NotificationType.TODO_STATUS_IN_PROGRESS,
            referenceType = NotificationReferenceType.TODO,
            referenceId = todoId.toString(),
            actorId = actor.id,
            payload = payload,
        )

        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.TODO_STATUS_IN_PROGRESS,
                actor.id,
                NotificationReferenceType.TODO,
                todoId.toString(),
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(4)

        listener.handleTodoStatusChanged(
            TodoStatusChangedEvent(
                todoId = todoId,
                actorId = actor.id!!,
                recipientMemberId = member.id!!,
                todoTitle = "보고서 정리",
                newStatus = TodoStatus.IN_PROGRESS,
            )
        )

        verify(notificationService).createNotification(
            member.id!!,
            NotificationType.TODO_STATUS_IN_PROGRESS,
            actor.id,
            NotificationReferenceType.TODO,
            todoId.toString(),
            payload,
        )
        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.TODO_STATUS_IN_PROGRESS)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/todo")
        assertThat(payloadCaptor.firstValue.unreadCount).isEqualTo(4)
    }

    @Test
    fun `handleTodoStatusChanged supports todo and done statuses`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "actor")
        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        data class TodoCase(
            val status: TodoStatus,
            val type: NotificationType,
            val payload: NotificationPayload,
        )

        val cases = listOf(
            TodoCase(
                status = TodoStatus.TODO,
                type = NotificationType.TODO_STATUS_TODO,
                payload = TodoStatusTodoPayload(actor = actorSnapshot(actor), todoTitle = "초안 작성"),
            ),
            TodoCase(
                status = TodoStatus.DONE,
                type = NotificationType.TODO_STATUS_DONE,
                payload = TodoStatusDonePayload(actor = actorSnapshot(actor), todoTitle = "초안 작성"),
            ),
        )

        cases.forEachIndexed { index, testCase ->
            val todoId = UUID.randomUUID()
            whenever(
                notificationService.createNotification(
                    member.id!!,
                    testCase.type,
                    actor.id,
                    NotificationReferenceType.TODO,
                    todoId.toString(),
                    testCase.payload,
                )
            ).thenReturn(
                notificationWith(
                    member = member,
                    type = testCase.type,
                    referenceType = NotificationReferenceType.TODO,
                    referenceId = todoId.toString(),
                    actorId = actor.id,
                    payload = testCase.payload,
                )
            )

            listener.handleTodoStatusChanged(
                TodoStatusChangedEvent(
                    todoId = todoId,
                    actorId = actor.id!!,
                    recipientMemberId = member.id!!,
                    todoTitle = "초안 작성",
                    newStatus = testCase.status,
                )
            )

            verify(notificationService).createNotification(
                member.id!!,
                testCase.type,
                actor.id,
                NotificationReferenceType.TODO,
                todoId.toString(),
                testCase.payload,
            )
        }

        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService, times(2)).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.allValues.map { it.type }).containsExactly(
            NotificationType.TODO_STATUS_TODO,
            NotificationType.TODO_STATUS_DONE,
        )
        assertThat(payloadCaptor.allValues.map { it.url }).containsOnly("/todo")
    }

    @Test
    fun `handleFamilyRequestAccepted uses friends url`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "family")
        val payload = FamilyRequestAcceptedPayload(actor = actorSnapshot(actor))
        val notification = notificationWith(
            member = member,
            type = NotificationType.FAMILY_REQUEST_ACCEPTED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = null,
            actorId = actor.id,
            payload = payload,
        )

        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FAMILY_REQUEST_ACCEPTED,
                actor.id,
                NotificationReferenceType.FRIEND_REQUEST,
                null,
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        listener.handleFamilyRequestAccepted(FamilyRequestAcceptedEvent(99L, member.id!!, actor.id!!))

        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/friends")
    }

    @Test
    fun `handleFamilyRequestSent uses friends url`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "sender")
        val requestId = 10L
        val payload = FamilyRequestReceivedPayload(actor = actorSnapshot(actor))
        val notification = notificationWith(
            member = member,
            type = NotificationType.FAMILY_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = requestId.toString(),
            actorId = actor.id,
            payload = payload,
        )

        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FAMILY_REQUEST_RECEIVED,
                actor.id,
                NotificationReferenceType.FRIEND_REQUEST,
                requestId.toString(),
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        listener.handleFamilyRequestSent(FamilyRequestSentEvent(requestId, actor.id!!, member.id!!))

        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.FAMILY_REQUEST_RECEIVED)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/friends")
    }

    @Test
    fun `handleFriendRequestAccepted uses friends url`() {
        val member = memberWithId(1L, "receiver")
        val actor = memberWithId(2L, "friend")
        val payload = FriendRequestAcceptedPayload(actor = actorSnapshot(actor))
        val notification = notificationWith(
            member = member,
            type = NotificationType.FRIEND_REQUEST_ACCEPTED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = null,
            actorId = actor.id,
            payload = payload,
        )

        whenever(memberRepository.findById(actor.id!!)).thenReturn(Optional.of(actor))
        whenever(
            notificationService.createNotification(
                member.id!!,
                NotificationType.FRIEND_REQUEST_ACCEPTED,
                actor.id,
                NotificationReferenceType.FRIEND_REQUEST,
                null,
                payload,
            )
        ).thenReturn(notification)
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(member.id!!)).thenReturn(1)

        listener.handleFriendRequestAccepted(FriendRequestAcceptedEvent(99L, member.id!!, actor.id!!))

        val payloadCaptor = argumentCaptor<PushNotificationPayload>()
        verify(webPushService).sendToMember(eq(member.id!!), payloadCaptor.capture())
        assertThat(payloadCaptor.firstValue.type).isEqualTo(NotificationType.FRIEND_REQUEST_ACCEPTED)
        assertThat(payloadCaptor.firstValue.url).isEqualTo("/friends")
    }

    @Test
    fun `listener swallows failures from notification creation`() {
        whenever(
            notificationService.createNotification(
                any(),
                any(),
                any(),
                any(),
                any(),
                any(),
            )
        ).doThrow(RuntimeException("boom"))

        assertDoesNotThrow {
            listener.handleFriendRequestSent(FriendRequestSentEvent(1L, 2L, 3L))
        }

        verifyNoInteractions(webPushService)
    }

    private fun notificationWith(
        member: Member,
        type: NotificationType,
        referenceType: NotificationReferenceType?,
        referenceId: String?,
        actorId: Long?,
        payload: NotificationPayload,
    ): Notification {
        return Notification(
            member = member,
            type = type,
            referenceType = referenceType,
            referenceId = referenceId,
            actorId = actorId,
            payloadJson = """{"version":${payload.version}}""",
            payloadVersion = payload.version,
        ).also {
            ReflectionTestUtils.setField(it, "id", UUID.randomUUID())
        }
    }

    private fun actorSnapshot(actor: Member): NotificationActorSnapshot {
        return NotificationActorSnapshot(
            name = actor.name,
            hasProfilePhoto = actor.hasProfilePhoto(),
            profilePhotoVersion = actor.profilePhotoVersion,
        )
    }

    private fun memberWithId(id: Long, name: String): Member {
        val member = Member(name = name, email = "$name@duty.park", password = "password")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }
}
