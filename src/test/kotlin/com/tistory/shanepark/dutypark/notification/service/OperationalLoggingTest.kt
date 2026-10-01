package com.tistory.shanepark.dutypark.notification.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentPermissionEvaluator
import com.tistory.shanepark.dutypark.attachment.service.AttachmentUploadSessionService
import com.tistory.shanepark.dutypark.common.datagokr.DataGoKrApi
import com.tistory.shanepark.dutypark.holiday.service.holidayAPI.HolidayAPIDataGoKr
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.push.apns.service.ApnsInstallationService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory
import org.springframework.test.util.ReflectionTestUtils
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.Clock
import java.time.LocalDateTime

class OperationalLoggingTest {
    @Test
    fun `APNs registration waits for commit and excludes device and refresh credentials`() {
        val repository: ApnsInstallationRepository = mock()
        val refreshRepository: RefreshTokenRepository = mock()
        val member = Member("member", "private@email", "password")
        ReflectionTestUtils.setField(member, "id", 12L)
        val token = RefreshToken(member, LocalDateTime.now().plusDays(1), null, null)
        ReflectionTestUtils.setField(token, "id", 34L)
        whenever(refreshRepository.findByToken("refresh-secret")).thenReturn(token)
        whenever(repository.save(any<com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation>())).thenAnswer { it.arguments[0] }
        capture(ApnsInstallationService::class.java) { events ->
            TransactionSynchronizationManager.initSynchronization()
            try {
                ApnsInstallationService(repository, refreshRepository).register(
                    LoginMember(12L, name = "member"), "refresh-secret", "device-secret", true,
                )
                assertThat(events).isEmpty()
                TransactionSynchronizationManager.getSynchronizations().forEach { it.afterCommit() }
                assertThat(events.map { it.formattedMessage }).singleElement().asString()
                    .contains("apns_installation_registered", "34", "12", "sandbox")
                    .doesNotContain("refresh-secret", "device-secret", "private@email")
            } finally {
                TransactionSynchronizationManager.clearSynchronization()
            }
        }
    }

    @Test
    fun `upload session creation logs owner and context only after save`() {
        val repository: AttachmentUploadSessionRepository = mock()
        whenever(repository.save(any<com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession>())).thenAnswer { it.arguments[0] }
        capture(AttachmentUploadSessionService::class.java) { events ->
            AttachmentUploadSessionService(repository, mock<AttachmentPermissionEvaluator>(), Clock.systemUTC())
                .createSession(LoginMember(12L, name = "member"), AttachmentContextType.SCHEDULE, "schedule-id")
            assertThat(events.map { it.formattedMessage }).singleElement().asString()
                .contains("attachment_upload_session_created", "12", "SCHEDULE", "schedule-id")
        }
    }

    @Test
    fun `holiday provider failure logs safe cause and year without credentials or exception message`() {
        val api: DataGoKrApi = mock()
        whenever(api.getHolidays(any(), any())).thenThrow(IllegalStateException("service-key-secret raw response"))
        capture(HolidayAPIDataGoKr::class.java) { events ->
            assertThatThrownBy { HolidayAPIDataGoKr(api, "service-key-secret").requestHolidays(2026) }
                .isInstanceOf(IllegalStateException::class.java)
            assertThat(events.map { it.formattedMessage }).singleElement().asString()
                .contains("holiday_api_fetch_failed", "2026", "IllegalStateException", "durationMs")
                .doesNotContain("service-key-secret", "raw response")
        }
    }

    @Test
    fun `notification cleanup logs committed deletion only and skips empty cleanup`() {
        val repository: NotificationRepository = mock()
        whenever(repository.deleteByCreatedDateBefore(any())).thenReturn(4, 0)
        capture(NotificationCleanupScheduler::class.java) { events ->
            TransactionSynchronizationManager.initSynchronization()
            try {
                val scheduler = NotificationCleanupScheduler(repository, Clock.systemUTC())
                scheduler.cleanupOldNotifications()
                scheduler.cleanupOldNotifications()
                assertThat(events).isEmpty()
                TransactionSynchronizationManager.getSynchronizations().forEach { it.afterCommit() }
                assertThat(events.map { it.formattedMessage }).singleElement().asString()
                    .contains("notification_cleanup_completed", "4", "cutoffDate")
            } finally {
                TransactionSynchronizationManager.clearSynchronization()
            }
        }
    }

    @Test
    fun `Web Push subscription records actor and original member but skips identical subscriptions`() {
        val repository: RefreshTokenRepository = mock()
        val member = Member("member", "private@email", "password")
        ReflectionTestUtils.setField(member, "id", 12L)
        val token = RefreshToken(member, LocalDateTime.now().plusDays(1), null, null)
        ReflectionTestUtils.setField(token, "id", 34L)
        val request = com.tistory.shanepark.dutypark.push.dto.PushSubscriptionRequest(
            "endpoint-secret",
            com.tistory.shanepark.dutypark.push.dto.PushSubscriptionKeys("p256-secret", "auth-secret"),
        )
        capture(com.tistory.shanepark.dutypark.push.service.WebPushService::class.java) { events ->
            val service = com.tistory.shanepark.dutypark.push.service.WebPushService(repository, mock(), mock())
            val actor = com.tistory.shanepark.dutypark.common.logging.AuditActor(12L, "effective", 99L)
            service.subscribe(token, request, actor)
            service.subscribe(token, request, actor)
            assertThat(events.map { it.formattedMessage }).singleElement().asString()
                .contains("web_push_subscription_registered", "34", "12", "effective", "originalMemberId", "99")
                .doesNotContain("endpoint-secret", "p256-secret", "auth-secret", "private@email")
        }
    }

    @Test
    fun `notification deletion emits only for affected rows`() {
        val repository: NotificationRepository = mock()
        whenever(repository.deleteByMemberIdAndIsReadTrue(12L)).thenReturn(3, 0)
        capture(NotificationService::class.java) { events ->
            val service = NotificationService(repository, mock(), mock(), mock())
            assertThat(service.deleteAllRead(12L)).isEqualTo(3)
            assertThat(service.deleteAllRead(12L)).isZero()
            assertThat(events.map { it.formattedMessage }).singleElement().asString()
                .contains("read_notifications_deleted", "12", "3")
        }
    }

    @Test
    fun `APNs update skips identical registration and records reassignment and environment change`() {
        val repository: ApnsInstallationRepository = mock()
        val refreshRepository: RefreshTokenRepository = mock()
        val member = Member("member", "private@email", "password")
        ReflectionTestUtils.setField(member, "id", 12L)
        val previous = RefreshToken(member, LocalDateTime.now().plusDays(1), null, null)
        val current = RefreshToken(member, LocalDateTime.now().plusDays(1), null, null)
        ReflectionTestUtils.setField(previous, "id", 33L)
        ReflectionTestUtils.setField(current, "id", 34L)
        val installation = com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation(previous, "device-secret", false)
        whenever(refreshRepository.findByToken("refresh-secret")).thenReturn(current)
        whenever(repository.findByDeviceToken("device-secret")).thenReturn(installation)
        capture(ApnsInstallationService::class.java) { events ->
            val service = ApnsInstallationService(repository, refreshRepository)
            service.register(LoginMember(12L, name = "member"), "refresh-secret", "device-secret", true)
            service.register(LoginMember(12L, name = "member"), "refresh-secret", "device-secret", true)
            assertThat(events.map { it.formattedMessage }).singleElement().asString()
                .contains("apns_installation_updated", "33", "34", "sandbox", "before", "after")
                .doesNotContain("device-secret", "refresh-secret", "private@email")
        }
    }

    @Test
    fun `holiday fetch result logs count and year without response body`() {
        val api: DataGoKrApi = mock()
        whenever(api.getHolidays(any(), any())).thenReturn("<response><items/></response>")
        capture(HolidayAPIDataGoKr::class.java) { events ->
            assertThat(HolidayAPIDataGoKr(api, "service-key-secret").requestHolidays(2026)).isEmpty()
            assertThat(events.map { it.formattedMessage }).singleElement().asString()
                .contains("holiday_api_fetch_completed", "2026", "holidayCount", "durationMs")
                .doesNotContain("service-key-secret", "<response>")
        }
    }

    private fun capture(type: Class<*>, block: (List<ILoggingEvent>) -> Unit) {
        val logger = LoggerFactory.getLogger(type) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try { block(appender.list) } finally { logger.detachAppender(appender); appender.stop() }
    }
}
