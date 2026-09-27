package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import org.springframework.scheduling.annotation.Scheduled
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.Instant
import java.nio.file.Files

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
    private val systemActor = AuditActor(id = null, name = "system:attachment-cleanup")

    @Scheduled(cron = "0 0 2 * * *")
    @Transactional
    fun cleanupExpiredSessions() {
        val now = Instant.now(clock)
        val expiredSessions = sessionRepository.findAllByExpiresAtBefore(now)

        if (expiredSessions.isEmpty()) {
            return
        }

        var attachmentsRemoved = 0
        var attachmentFailures = 0
        var directoriesRemoved = 0
        var directoriesAlreadyAbsent = 0
        var directoryFailures = 0
        val sessionResults = mutableListOf<Map<String, Any?>>()

        expiredSessions.forEach { session ->
            val sessionId = session.id
            val attachments = attachmentRepository.findAllByUploadSessionId(sessionId)
            val removedBeforeSession = attachmentsRemoved
            val attachmentFailuresBeforeSession = attachmentFailures

            attachments.forEach { attachment ->
                runCatching {
                    attachmentService.deleteAttachment(
                        attachment,
                        actor = systemActor,
                        reason = "expired_upload_session"
                    )
                    attachmentsRemoved++
                }.onFailure { ex ->
                    attachmentFailures++
                    log.error(
                        "Expired-session attachment removal failed: {}",
                        auditContext(
                            mapOf(
                                "actor" to systemActor,
                                "attachmentId" to attachment.id,
                                "contextType" to attachment.contextType,
                                "contextId" to attachment.contextId,
                                "uploadSessionId" to sessionId,
                                "ownerId" to attachment.createdBy,
                                "ownerName" to null,
                                "filename" to attachment.originalFilename
                            ) + ex.toAttachmentLogDiagnostics()
                        )
                    )
                }
            }

            val tempDir = pathResolver.resolveTemporaryDirectory(sessionId)
            var directoryResult = "removed"
            runCatching {
                val existed = Files.exists(tempDir)
                fileSystemService.deleteDirectory(tempDir)
                if (!existed) {
                    directoryResult = "already_absent"
                    directoriesAlreadyAbsent++
                } else if (Files.exists(tempDir)) {
                    directoryResult = "still_exists"
                    directoryFailures++
                    log.warn(
                        "Expired-session temporary directory remains after cleanup: {}",
                        auditContext(
                            mapOf(
                                "actor" to systemActor,
                                "sessionId" to sessionId,
                                "contextType" to session.contextType,
                                "contextId" to session.targetContextId,
                                "ownerId" to session.ownerId,
                                "ownerName" to null,
                                "path" to tempDir.toString()
                            )
                        )
                    )
                } else {
                    directoriesRemoved++
                }
            }.onFailure { ex ->
                directoryResult = "failed"
                directoryFailures++
                log.error(
                    "Expired-session temporary directory cleanup failed: {}",
                    auditContext(
                        mapOf(
                            "actor" to systemActor,
                            "sessionId" to sessionId,
                            "contextType" to session.contextType,
                            "contextId" to session.targetContextId,
                            "ownerId" to session.ownerId,
                            "ownerName" to null,
                            "path" to tempDir.toString()
                        ) + ex.toAttachmentLogDiagnostics()
                    )
                )
            }

            sessionResults += mapOf(
                "sessionId" to sessionId,
                "contextType" to session.contextType,
                "contextId" to session.targetContextId,
                "ownerId" to session.ownerId,
                "ownerName" to null,
                "expiresAt" to session.expiresAt,
                "attachmentCount" to attachments.size,
                "attachmentsRemoved" to attachmentsRemoved - removedBeforeSession,
                "attachmentFailures" to attachmentFailures - attachmentFailuresBeforeSession,
                "temporaryDirectoryResult" to directoryResult
            )
        }

        var sessionDeleteFailed = false
        runCatching {
            sessionRepository.deleteAll(expiredSessions)
        }.onFailure { ex ->
            sessionDeleteFailed = true
            log.error(
                "Expired attachment upload-session removal failed: {}",
                auditContext(
                    mapOf(
                        "actor" to systemActor,
                        "sessionIds" to expiredSessions.map { it.id },
                        "sessionCount" to expiredSessions.size
                    ) + ex.toAttachmentLogDiagnostics()
                )
            )
        }

        if (!sessionDeleteFailed) {
            expiredSessions.forEachIndexed { index, session ->
                val result = sessionResults[index]
                log.auditEventAfterCommit(
                    event = "attachment.upload_session.expired_and_removed",
                    actor = systemActor,
                    target = mapOf(
                        "type" to "AttachmentUploadSession",
                        "id" to session.id,
                        "contextType" to session.contextType,
                        "contextId" to session.targetContextId,
                        "ownerId" to session.ownerId,
                        "ownerName" to null
                    ),
                    details = result.filterKeys { it != "sessionId" }
                )
            }
        }
        log.auditEventAfterCommit(
            event = "attachment.expired_session_cleanup.completed",
            actor = systemActor,
            target = mapOf("type" to "AttachmentCleanupJob", "runAt" to now),
            details = mapOf(
                "expiredSessionIds" to expiredSessions.map { it.id },
                "expiredSessionCount" to expiredSessions.size,
                "sessionDeletionSucceeded" to !sessionDeleteFailed,
                "attachmentsRemoved" to attachmentsRemoved,
                "attachmentFailures" to attachmentFailures,
                "temporaryDirectoriesRemoved" to directoriesRemoved,
                "temporaryDirectoriesAlreadyAbsent" to directoriesAlreadyAbsent,
                "temporaryDirectoryFailures" to directoryFailures
            )
        )
    }
}
