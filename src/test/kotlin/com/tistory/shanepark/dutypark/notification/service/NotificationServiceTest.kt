package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.notification.domain.entity.Notification
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationReferenceType
import com.tistory.shanepark.dutypark.notification.domain.enums.NotificationType
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.*
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.PageRequest
import org.springframework.test.util.ReflectionTestUtils
import java.util.*

@ExtendWith(MockitoExtension::class)
class NotificationServiceTest {

    @Mock
    private lateinit var notificationRepository: NotificationRepository

    @Mock
    private lateinit var memberRepository: MemberRepository

    private lateinit var notificationService: NotificationService

    private lateinit var testMember: Member
    private lateinit var actorMember: Member

    @BeforeEach
    fun setUp() {
        notificationService = NotificationService(notificationRepository, memberRepository)

        testMember = Member(name = "testUser", email = "test@test.com", password = "password")
        ReflectionTestUtils.setField(testMember, "id", 1L)

        actorMember = Member(name = "actorUser", email = "actor@test.com", password = "password")
        ReflectionTestUtils.setField(actorMember, "id", 2L)
    }

    @Test
    fun `getUnreadNotifications returns notifications with actor info`() {
        // Given
        val notification = createNotification(testMember, actorMember.id, isRead = false)
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(listOf(notification))
        whenever(memberRepository.findAllById(listOf(actorMember.id!!)))
            .thenReturn(listOf(actorMember))

        // When
        val result = notificationService.getUnreadNotifications(testMember.id!!)

        // Then
        assertThat(result).hasSize(1)
        assertThat(result[0].actorName).isEqualTo(actorMember.name)
        assertThat(result[0].isRead).isFalse()
    }

    @Test
    fun `getUnreadNotifications limits to 50 notifications`() {
        // Given
        val notifications = (1..60).map { createNotification(testMember, actorMember.id, isRead = false) }
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(notifications)
        whenever(memberRepository.findAllById(any()))
            .thenReturn(listOf(actorMember))

        // When
        val result = notificationService.getUnreadNotifications(testMember.id!!)

        // Then
        assertThat(result).hasSize(50)
    }

    @Test
    fun `getNotifications returns paged notifications`() {
        // Given
        val pageable = PageRequest.of(0, 10)
        val notifications = listOf(createNotification(testMember, actorMember.id))
        val page = PageImpl(notifications, pageable, 1)

        whenever(notificationRepository.findByMemberIdOrderByCreatedDateDesc(testMember.id!!, pageable))
            .thenReturn(page)
        whenever(memberRepository.findAllById(listOf(actorMember.id!!)))
            .thenReturn(listOf(actorMember))

        // When
        val result = notificationService.getNotifications(testMember.id!!, pageable)

        // Then
        assertThat(result.content).hasSize(1)
        assertThat(result.totalElements).isEqualTo(1)
    }

    @Test
    fun `getUnreadCount returns correct counts`() {
        // Given
        whenever(notificationRepository.countByMemberIdAndIsReadFalse(testMember.id!!))
            .thenReturn(5L)
        whenever(notificationRepository.countByMemberId(testMember.id!!))
            .thenReturn(10L)

        // When
        val result = notificationService.getUnreadCount(testMember.id!!)

        // Then
        assertThat(result.unreadCount).isEqualTo(5)
        assertThat(result.totalCount).isEqualTo(10)
    }

    @Test
    fun `markAsRead marks notification as read`() {
        // Given
        val notification = createNotification(testMember, actorMember.id, isRead = false)
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notification.id))
            .thenReturn(notification)
        whenever(notificationRepository.save(notification))
            .thenReturn(notification)
        whenever(memberRepository.findById(actorMember.id!!))
            .thenReturn(Optional.of(actorMember))

        // When
        val result = notificationService.markAsRead(testMember.id!!, notification.id)

        // Then
        assertThat(result.isRead).isTrue()
        assertThat(notification.isRead).isTrue()
        verify(notificationRepository).save(notification)
    }

    @Test
    fun `markAsRead throws exception when notification not found`() {
        // Given
        val notificationId = UUID.randomUUID()
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notificationId))
            .thenReturn(null)

        // When & Then
        assertThatThrownBy { notificationService.markAsRead(testMember.id!!, notificationId) }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("Notification not found")
    }

    @Test
    fun `markAllAsRead marks all unread notifications as read`() {
        // Given
        val notifications = listOf(
            createNotification(testMember, actorMember.id, isRead = false),
            createNotification(testMember, actorMember.id, isRead = false)
        )
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(notifications)

        // When
        val count = notificationService.markAllAsRead(testMember.id!!)

        // Then
        assertThat(count).isEqualTo(2)
        notifications.forEach { assertThat(it.isRead).isTrue() }
        verify(notificationRepository).saveAll(notifications)
    }

    @Test
    fun `deleteNotification deletes existing notification`() {
        // Given
        val notification = createNotification(testMember, actorMember.id)
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notification.id))
            .thenReturn(notification)

        // When
        notificationService.deleteNotification(testMember.id!!, notification.id)

        // Then
        verify(notificationRepository).delete(notification)
    }

    @Test
    fun `deleteNotification throws exception when notification not found`() {
        // Given
        val notificationId = UUID.randomUUID()
        whenever(notificationRepository.findByMemberIdAndId(testMember.id!!, notificationId))
            .thenReturn(null)

        // When & Then
        assertThatThrownBy { notificationService.deleteNotification(testMember.id!!, notificationId) }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("Notification not found")
    }

    @Test
    fun `deleteAllRead deletes all read notifications`() {
        // Given
        whenever(notificationRepository.deleteByMemberIdAndIsReadTrue(testMember.id!!))
            .thenReturn(3)

        // When
        val count = notificationService.deleteAllRead(testMember.id!!)

        // Then
        assertThat(count).isEqualTo(3)
        verify(notificationRepository).deleteByMemberIdAndIsReadTrue(testMember.id!!)
    }

    @Test
    fun `createNotification creates notification with generated title`() {
        // Given
        whenever(memberRepository.findById(testMember.id!!))
            .thenReturn(Optional.of(testMember))
        whenever(memberRepository.findById(actorMember.id!!))
            .thenReturn(Optional.of(actorMember))
        whenever(notificationRepository.save(any<Notification>()))
            .thenAnswer { it.arguments[0] }

        // When
        val result = notificationService.createNotification(
            memberId = testMember.id!!,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            actorId = actorMember.id,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            content = null
        )

        // Then
        assertThat(result.title).isEqualTo("actorUser님이 친구 요청을 보냈습니다")
        assertThat(result.type).isEqualTo(NotificationType.FRIEND_REQUEST_RECEIVED)
        assertThat(result.member).isEqualTo(testMember)
        assertThat(result.actorId).isEqualTo(actorMember.id)
        verify(notificationRepository).save(any<Notification>())
    }

    @Test
    fun `createNotification throws exception when member not found`() {
        // Given
        val nonExistentMemberId = 999L
        whenever(memberRepository.findById(nonExistentMemberId))
            .thenReturn(Optional.empty())

        // When & Then
        assertThatThrownBy {
            notificationService.createNotification(
                memberId = nonExistentMemberId,
                type = NotificationType.FRIEND_REQUEST_RECEIVED,
                actorId = actorMember.id,
                referenceType = null,
                referenceId = null,
                content = null
            )
        }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("Member not found: 999")
    }

    @Test
    fun `createNotification handles null actorId with Unknown name`() {
        // Given
        whenever(memberRepository.findById(testMember.id!!))
            .thenReturn(Optional.of(testMember))
        whenever(notificationRepository.save(any<Notification>()))
            .thenAnswer { it.arguments[0] }

        // When
        val result = notificationService.createNotification(
            memberId = testMember.id!!,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            actorId = null,
            referenceType = null,
            referenceId = null,
            content = null
        )

        // Then
        assertThat(result.title).isEqualTo("Unknown님이 친구 요청을 보냈습니다")
    }

    @Test
    fun `enrichWithActorInfo handles empty actor list`() {
        // Given
        val notification = createNotification(testMember, actorId = null)
        whenever(notificationRepository.findByMemberIdAndIsReadFalseOrderByCreatedDateDesc(testMember.id!!))
            .thenReturn(listOf(notification))

        // When
        val result = notificationService.getUnreadNotifications(testMember.id!!)

        // Then
        assertThat(result).hasSize(1)
        assertThat(result[0].actorName).isNull()
        verify(memberRepository, never()).findAllById(any())
    }

    private fun createNotification(
        member: Member,
        actorId: Long? = null,
        isRead: Boolean = false
    ): Notification {
        return Notification(
            member = member,
            type = NotificationType.FRIEND_REQUEST_RECEIVED,
            title = "Test notification",
            content = null,
            referenceType = NotificationReferenceType.FRIEND_REQUEST,
            referenceId = "123",
            actorId = actorId
        ).apply {
            this.isRead = isRead
        }
    }
}
