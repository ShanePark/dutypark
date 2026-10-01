package com.tistory.shanepark.dutypark.notification.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Component
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDateTime

@Component
class NotificationCleanupScheduler(
    private val notificationRepository: NotificationRepository,
    private val clock: Clock
) {
    private val log = logger()

    @Scheduled(cron = "0 30 2 * * *")
    @Transactional
    fun cleanupOldNotifications() {
        val cutoffDate = LocalDateTime.now(clock).minusDays(30)
        val deletedCount = notificationRepository.deleteByCreatedDateBefore(cutoffDate)

        if (deletedCount > 0) {
            log.auditEventAfterCommit(
                "notification_cleanup_completed", null,
                details = mapOf("deletedCount" to deletedCount, "cutoffDate" to cutoffDate),
            )
        }
    }
}
