package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Instant

@Service
class AttachmentCleanupScheduler(
    private val attachmentRepository: AttachmentRepository,
    private val sessionRepository: AttachmentUploadSessionRepository,
    private val attachmentService: AttachmentService,
    private val pathResolver: StoragePathResolver,
    private val fileSystemService: FileSystemService,
    private val clock: Clock
) {
    private val log = logger()

    @Scheduled(cron = "0 0 2 * * *")
    @Transactional
    fun cleanupExpiredSessions() {
        val now = Instant.now(clock)
        val expiredSessions = sessionRepository.findAllByExpiresAtBefore(now)

        if (expiredSessions.isEmpty()) {
            log.debug("No expired attachment sessions to clean up at {}", now)
            return
        }

        var attachmentsRemoved = 0

        expiredSessions.forEach { session ->
            val sessionId = session.id
            val attachments = attachmentRepository.findAllByUploadSessionId(sessionId)

            attachments.forEach { attachment ->
                runCatching {
                    attachmentService.deleteAttachment(attachment)
                    attachmentsRemoved++
                }.onFailure { ex ->
                    log.warn(
                        "Failed to delete attachment {} for expired session {}: {}",
                        attachment.id,
                        sessionId,
                        ex.message
                    )
                }
            }

            val tempDir = pathResolver.resolveTemporaryDirectory(sessionId)
            runCatching {
                fileSystemService.deleteDirectory(tempDir)
            }.onFailure { ex ->
                log.warn(
                    "Failed to delete temporary directory {} for session {}: {}",
                    tempDir,
                    sessionId,
                    ex.message
                )
            }
        }

        runCatching {
            sessionRepository.deleteAll(expiredSessions)
        }.onFailure { ex ->
            log.warn("Failed to delete expired sessions: {}", ex.message)
        }

        log.info(
            "Expired session cleanup removed {} attachments across {} sessions",
            attachmentsRemoved,
            expiredSessions.size
        )
    }
}
