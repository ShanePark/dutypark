package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.payload.FriendRequestReceivedPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationActorSnapshot
import com.tistory.shanepark.dutypark.notification.domain.payload.NotificationPayload
import com.tistory.shanepark.dutypark.notification.domain.payload.ScheduleTaggedPayload
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
import org.springframework.test.util.ReflectionTestUtils
import tools.jackson.module.kotlin.jacksonMapperBuilder
import java.util.Optional
import java.util.UUID

@ExtendWith(MockitoExtension::class)
class NotificationServiceTest {

    @Mock
    private lateinit var notificationRepository: NotificationRepository

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var friendRequestRepository: FriendRequestRepository

    private lateinit var notificationPayloadCodec: NotificationPayloadCodec
    private lateinit var notificationService: NotificationService

    private lateinit var testMember: Member
    private lateinit var actorMember: Member

    @BeforeEach
    fun setUp() {
        notificationPayloadCodec = NotificationPayloadCodec(jacksonMapperBuilder().build())
        notificationService = NotificationService(
            notificationRepository = notificationRepository,
            memberRepository = memberRepository,
            friendRequestRepository = friendRequestRepository,
            notificationPayloadCodec = notificationPayloadCodec,
        )

        testMember = Member(name = "testUser", email = "test@test.com", password = "password")
        ReflectionTestUtils.setField(testMember, "id", 1L)

        actorMember = Member(name = "actorUser", email = "actor@test.com", password = "password")
        ReflectionTestUtils.setField(actorMember, "id", 2L)
        actorMember.profilePhotoPath = "profile.jpg"
        actorMember.profilePhotoVersion = 7
    }

    @Test
    fun `getUnreadNotifications returns payload snapshot without extra actor lookup`() {
        val payload = friendRequestPayload(actorMember)
        val notification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = payload,
            actorId = actorMember.id,
            isRead = false,
        )
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(listOf(notification))

        val result = notificationService.getUnreadNotifications(testMember.id!!)

        assertThat(result).hasSize(1)
        assertThat(result[0].payload).isEqualTo(payload)
        assertThat(result[0].payload.version).isEqualTo(1)
        assertThat((result[0].payload as FriendRequestReceivedPayload).actor.name).isEqualTo(actorMember.name)
        verify(memberRepository, never()).findAllById(any<Iterable<Long>>())
    }

    @Test
    fun `getUnreadNotifications limits to 50 notifications`() {
        val payload = friendRequestPayload(actorMember)
        val notifications = (1..60).map {
            storedNotification(
                member = testMember,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                payload = payload,
                actorId = actorMember.id,
                isRead = false,
            )
        }
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(notifications)

        val result = notificationService.getUnreadNotifications(testMember.id!!)

        assertThat(result).hasSize(50)
    }

    @Test
    fun `getNotifications returns paged notifications`() {
        val pageable = PageRequest.of(0, 10)
        val payload = friendRequestPayload(actorMember)
        val notification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = payload,
            actorId = actorMember.id,
        )
        whenever(notificationRepository.findByMemberIdOrderByCreatedDateDesc(testMember.id!!, pageable))
            .thenReturn(PageImpl(listOf(notification), pageable, 1))

        val result = notificationService.getNotifications(testMember.id!!, pageable)

        assertThat(result.content).hasSize(1)
        assertThat(result.content[0].payload).isEqualTo(payload)
        assertThat(result.content[0].actorId).isEqualTo(actorMember.id)
        assertThat(result.totalElements).isEqualTo(1)
    }

    @Test
    fun `getNotifications returns generic payload when page contains invalid rows`() {
        val pageable = PageRequest.of(0, 10)
        val validPayload = friendRequestPayload(actorMember)
        val validNotification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = validPayload,
            actorId = actorMember.id,
        )
        val invalidNotification = Notification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "456",
            actorId = actorMember.id,
            payloadJson = notificationPayloadCodec.serialize(validPayload),
            payloadVersion = 2,
            isRead = false,
        ).also {
            ReflectionTestUtils.setField(it, "id", UUID.randomUUID())
        }
        whenever(notificationRepository.findByMemberIdOrderByCreatedDateDesc(testMember.id!!, pageable))
            .thenReturn(PageImpl(listOf(validNotification, invalidNotification), pageable, 2))

        val result = notificationService.getNotifications(testMember.id!!, pageable)

        assertThat(result.content).hasSize(2)
        assertThat(result.content[0].id).isEqualTo(validNotification.id)
        assertThat(result.content[1].id).isEqualTo(invalidNotification.id)
        assertThat(result.content[1].payload.version).isEqualTo(0)
        assertThat(result.totalElements).isEqualTo(2)
    }

    @Test
    fun `getUnreadCountSimple returns correct counts`() {
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(testMember.id!!)).thenReturn(1)
        whenever(notificationRepository.countByMemberId(testMember.id!!)).thenReturn(2)

        val result = notificationService.getUnreadCountSimple(testMember.id!!)

        assertThat(result.unreadCount).isEqualTo(1)
        assertThat(result.totalCount).isEqualTo(2)
        verify(notificationRepository).countByMemberIdAndIsReadFalse(testMember.id!!)
        verify(notificationRepository).countByMemberId(testMember.id!!)
    }

    @Test
    fun `getFriendRequestCount returns correct count`() {
        whenever(friendRequestRepository.countByToMemberIdAndStatus(testMember.id!!, FriendRequestStatus.PENDING))
            .thenReturn(3L)

        val result = notificationService.getFriendRequestCount(testMember.id!!)

        assertThat(result).isEqualTo(3)
    }

    @Test
    fun `markAsRead marks notification as read and returns payload dto`() {
        val payload = friendRequestPayload(actorMember)
        val notification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = payload,
            actorId = actorMember.id,
            isRead = false,
        )
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notification.id))
            .thenReturn(notification)
        whenever(notificationRepository.save(notification)).thenReturn(notification)

        val result = notificationService.markAsRead(testMember.id!!, notification.id)

        assertThat(result.isRead).isTrue()
        assertThat(result.payload).isEqualTo(payload)
        verify(notificationRepository).save(notification)
    }

    @Test
    fun `markAsRead throws exception when notification not found`() {
        val notificationId = UUID.randomUUID()
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notificationId))
            .thenReturn(null)

        assertThatThrownBy { notificationService.markAsRead(testMember.id!!, notificationId) }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("Notification not found")
    }

    @Test
    fun `markAllAsRead marks all unread notifications as read`() {
        val payload = friendRequestPayload(actorMember)
        val notifications = listOf(
            storedNotification(
                member = testMember,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                payload = payload,
                actorId = actorMember.id,
                isRead = false,
            ),
            storedNotification(
                member = testMember,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                payload = payload,
                actorId = actorMember.id,
                isRead = false,
            )
        )
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(notifications)

        val count = notificationService.markAllAsRead(testMember.id!!)

        assertThat(count).isEqualTo(2)
        notifications.forEach { assertThat(it.isRead).isTrue() }
        verify(notificationRepository).saveAll(notifications)
    }

    @Test
    fun `deleteNotification deletes existing notification`() {
        val notification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = friendRequestPayload(actorMember),
            actorId = actorMember.id,
        )
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notification.id))
            .thenReturn(notification)

        notificationService.deleteNotification(testMember.id!!, notification.id)

        verify(notificationRepository).delete(notification)
    }

    @Test
    fun `deleteNotification throws exception when notification not found`() {
        val notificationId = UUID.randomUUID()
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notificationId))
            .thenReturn(null)

        assertThatThrownBy { notificationService.deleteNotification(testMember.id!!, notificationId) }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("Notification not found")
    }

    @Test
    fun `deleteAllRead deletes all read notifications`() {
        whenever(notificationRepository.deleteByMemberIdAndIsReadTrue(testMember.id!!))
            .thenReturn(3)

        val count = notificationService.deleteAllRead(testMember.id!!)

        assertThat(count).isEqualTo(3)
        verify(notificationRepository).deleteByMemberIdAndIsReadTrue(testMember.id!!)
    }

    @Test
    fun `createNotification stores serialized payload and version`() {
        val payload = friendRequestPayload(actorMember)
        whenever(memberRepository.findById(testMember.id!!)).thenReturn(Optional.of(testMember))
        whenever(notificationRepository.save(any<Notification>())).thenAnswer { it.arguments[0] }

        val result = notificationService.createNotification(
            memberId = testMember.id!!,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            actorId = actorMember.id,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            payload = payload,
        )

        assertThat(result.payloadJson).isEqualTo(notificationPayloadCodec.serialize(payload))
        assertThat(result.payloadVersion).isEqualTo(payload.version)
    }

    @Test
    fun `createNotification rejects incompatible payload type`() {
        val payload = ScheduleTaggedPayload(
            actor = actorSnapshot(actorMember),
            scheduleTitle = "팀 회의",
        )
        whenever(memberRepository.findById(testMember.id!!)).thenReturn(Optional.of(testMember))

        assertThatThrownBy {
            notificationService.createNotification(
                memberId = testMember.id!!,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                actorId = actorMember.id,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = "123",
                payload = payload,
            )
        }
            .isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("Notification payload type mismatch for FRIEND_REQUEST_RECEIVED version 1")

        verify(notificationRepository, never()).save(any<Notification>())
    }

    @Test
    fun `createNotification stores typed payloads without legacy text columns`() {
        val payload = ScheduleTaggedPayload(
            actor = actorSnapshot(actorMember),
            scheduleTitle = "팀 회의",
        )
        whenever(memberRepository.findById(testMember.id!!)).thenReturn(Optional.of(testMember))
        whenever(notificationRepository.save(any<Notification>())).thenAnswer { it.arguments[0] }

        val result = notificationService.createNotification(
            memberId = testMember.id!!,
            type = NotificationType.SCHEDULE_TAGGED,
            actorId = actorMember.id,
            referenceType = NotificationReferenceType.SCHEDULE,
            referenceId = UUID.randomUUID().toString(),
            payload = payload,
        )

        assertThat(result.payloadJson).isEqualTo(notificationPayloadCodec.serialize(payload))
        assertThat(result.payloadVersion).isEqualTo(1)
    }

    @Test
    fun `createNotification throws exception when member not found`() {
        whenever(memberRepository.findById(999L)).thenReturn(Optional.empty())

        assertThatThrownBy {
            notificationService.createNotification(
                memberId = 999L,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                actorId = actorMember.id,
                referenceType = null,
                referenceId = null,
                payload = friendRequestPayload(actorMember),
            )
        }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("Member not found: 999")
    }

    @Test
    fun `getUnreadNotifications returns generic payload when payload data is missing`() {
        val validPayload = friendRequestPayload(actorMember)
        val validNotification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = validPayload,
            actorId = actorMember.id,
            isRead = false,
        )
        val invalidNotification = Notification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            actorId = actorMember.id,
            payloadJson = null,
            payloadVersion = 1,
            isRead = false,
        )
        ReflectionTestUtils.setField(invalidNotification, "id", UUID.randomUUID())
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(listOf(invalidNotification, validNotification))

        val result = notificationService.getUnreadNotifications(testMember.id!!)

        assertThat(result).hasSize(2)
        assertThat(result[0].id).isEqualTo(invalidNotification.id)
        assertThat(result[0].payload.version).isEqualTo(0)
        assertThat(result[1].id).isEqualTo(validNotification.id)
    }

    @Test
    fun `getUnreadNotifications keeps latest 50 notifications even when payload data is missing`() {
        val invalidNotifications = (1..50).map {
            Notification(
                member = testMember,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                referenceType = NotificationReferenceType.FRIEND_REQUEST,
                referenceId = "broken-$it",
                actorId = actorMember.id,
                payloadJson = null,
                payloadVersion = 1,
                isRead = false,
            ).also { notification ->
                ReflectionTestUtils.setField(notification, "id", UUID.randomUUID())
            }
        }
        val validNotification = storedNotification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            payload = friendRequestPayload(actorMember),
            actorId = actorMember.id,
            isRead = false,
        )
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(invalidNotifications + validNotification)

        val result = notificationService.getUnreadNotifications(testMember.id!!)

        assertThat(result).hasSize(50)
        assertThat(result).allMatch { it.payload.version == 0 }
    }

    @Test
    fun `getUnreadCountSimple uses repository counts without loading notification rows`() {
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(testMember.id!!)).thenReturn(2)
        whenever(notificationRepository.countByMemberId(testMember.id!!)).thenReturn(5)

        val result = notificationService.getUnreadCountSimple(testMember.id!!)

        assertThat(result.unreadCount).isEqualTo(2)
        assertThat(result.totalCount).isEqualTo(5)
        verify(notificationRepository).countByMemberIdAndIsReadFalse(testMember.id!!)
        verify(notificationRepository).countByMemberId(testMember.id!!)
    }

    @Test
    fun `markAsRead returns generic payload and persists read state when payload data is missing`() {
        val notification = Notification(
            member = testMember,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            actorId = actorMember.id,
            payloadJson = null,
            payloadVersion = 1,
            isRead = false,
        )
        ReflectionTestUtils.setField(notification, "id", UUID.randomUUID())
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notification.id))
            .thenReturn(notification)
        whenever(notificationRepository.save(notification)).thenReturn(notification)

        val result = notificationService.markAsRead(testMember.id!!, notification.id)

        assertThat(notification.isRead).isTrue()
        assertThat(result.isRead).isTrue()
        assertThat(result.payload.version).isEqualTo(0)
        verify(notificationRepository).save(notification)
    }

    private fun friendRequestPayload(actor: Member): FriendRequestReceivedPayload {
        return FriendRequestReceivedPayload(actor = actorSnapshot(actor))
    }

    private fun actorSnapshot(actor: Member): NotificationActorSnapshot {
        return NotificationActorSnapshot(
            name = actor.name,
            hasProfilePhoto = actor.hasProfilePhoto(),
            profilePhotoVersion = actor.profilePhotoVersion,
        )
    }

    private fun storedNotification(
        member: Member,
        type: NotificationType,
        payload: NotificationPayload,
        actorId: Long?,
        isRead: Boolean = false,
    ): Notification {
        return Notification(
            member = member,
            type = type,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            actorId = actorId,
            payloadJson = notificationPayloadCodec.serialize(payload),
            payloadVersion = payload.version,
            isRead = isRead,
        ).also {
            ReflectionTestUtils.setField(it, "id", UUID.randomUUID())
        }
    }
}
