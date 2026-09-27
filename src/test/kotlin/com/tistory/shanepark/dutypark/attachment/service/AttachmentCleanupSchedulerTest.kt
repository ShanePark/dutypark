package com.tistory.shanepark.dutypark.attachment.service

import ch.qos.logback.classic.Level
import ch.qos.logback.classic.Logger as LogbackLogger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.slf4j.LoggerFactory
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.mockito.kotlin.verify
import java.io.IOException
import java.nio.file.Path
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

class AttachmentCleanupSchedulerTest {

    @Test
    fun `cleanup failure log escapes exception details without raw throwable`() {
        val now = Instant.parse("2025-01-01T04:00:00Z")
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = "schedule-123",
            ownerId = 42L,
            expiresAt = now.minusSeconds(60)
        )
        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = null,
            uploadSessionId = session.id,
            originalFilename = "receipt\nprivate.txt",
            storedFilename = "stored.txt",
            contentType = "text/plain",
            size = 12L,
            storagePath = "/tmp/attachments",
            createdBy = session.ownerId
        )
        val attachmentRepository = mock<AttachmentRepository>()
        val sessionRepository = mock<AttachmentUploadSessionRepository>()
        val attachmentService = mock<AttachmentService>()
        val pathResolver = mock<StoragePathResolver>()
        val fileSystemService = mock<FileSystemService>()
        val tempDir = Path.of("/tmp/expired-attachment-session")
        whenever(sessionRepository.findAllByExpiresAtBefore(now)).thenReturn(listOf(session))
        whenever(attachmentRepository.findAllByUploadSessionId(session.id)).thenReturn(listOf(attachment))
        whenever(pathResolver.resolveTemporaryDirectory(session.id)).thenReturn(tempDir)
        doThrow(IOException("cleanup failed\nunsafe detail", IllegalStateException("cause\nunsafe detail")))
            .whenever(attachmentService)
            .deleteAttachment(
                eq(attachment),
                eq(AuditActor(id = null, name = "system:attachment-cleanup")),
                eq("expired_upload_session")
            )

        val scheduler = AttachmentCleanupScheduler(
            attachmentRepository,
            sessionRepository,
            attachmentService,
            pathResolver,
            fileSystemService,
            Clock.fixed(now, ZoneOffset.UTC)
        )
        val logger = LoggerFactory.getLogger(AttachmentCleanupScheduler::class.java) as LogbackLogger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            scheduler.cleanupExpiredSessions()
        } finally {
            logger.detachAppender(appender)
        }

        val event = appender.list.single { it.level == Level.ERROR }
        assertThat(event.throwableProxy).isNull()
        assertThat(event.formattedMessage)
            .doesNotContain("\n")
            .contains("system:attachment-cleanup")
            .contains(session.id.toString())
            .contains(attachment.id.toString())
            .contains("42")
            .contains("receipt\\nprivate.txt")
            .contains("java.io.IOException")
            .contains("java.lang.IllegalStateException")
            .contains("stackFrames")
            .doesNotContain("unsafe detail")

        val messages = appender.list.map { it.formattedMessage }
        assertThat(messages.single { it.contains("\"event\":\"attachment.upload_session.expired_and_removed\"") })
            .contains("\"id\":\"${session.id}\"", "\"temporaryDirectoryResult\":\"completed\"")
        assertThat(messages.single { it.contains("\"event\":\"attachment.expired_session_cleanup.completed\"") })
            .contains("\"temporaryDirectoryCleanupsCompleted\":1", "\"temporaryDirectoryFailures\":0")
            .doesNotContain("expiredSessionIds")
    }

    @Test
    fun `successful cleanup logs one completion count without duplicate session ids`() {
        val now = Instant.parse("2025-01-01T04:00:00Z")
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = "schedule-123",
            ownerId = 42L,
            expiresAt = now.minusSeconds(60)
        )
        val attachmentRepository = mock<AttachmentRepository>()
        val sessionRepository = mock<AttachmentUploadSessionRepository>()
        val attachmentService = mock<AttachmentService>()
        val pathResolver = mock<StoragePathResolver>()
        val fileSystemService = mock<FileSystemService>()
        val tempDir = Path.of("/tmp/expired-attachment-session-success")
        whenever(sessionRepository.findAllByExpiresAtBefore(now)).thenReturn(listOf(session))
        whenever(attachmentRepository.findAllByUploadSessionId(session.id)).thenReturn(emptyList())
        whenever(pathResolver.resolveTemporaryDirectory(session.id)).thenReturn(tempDir)

        val scheduler = AttachmentCleanupScheduler(
            attachmentRepository,
            sessionRepository,
            attachmentService,
            pathResolver,
            fileSystemService,
            Clock.fixed(now, ZoneOffset.UTC)
        )
        val logger = LoggerFactory.getLogger(AttachmentCleanupScheduler::class.java) as LogbackLogger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            scheduler.cleanupExpiredSessions()
        } finally {
            logger.detachAppender(appender)
        }

        verify(fileSystemService).deleteDirectory(tempDir)
        assertThat(appender.list.single { it.formattedMessage.contains("\"event\":\"attachment.upload_session.expired_and_removed\"") }.formattedMessage)
            .contains("\"id\":\"${session.id}\"", "\"temporaryDirectoryResult\":\"completed\"")
        assertThat(appender.list.single { it.formattedMessage.contains("\"event\":\"attachment.expired_session_cleanup.completed\"") }.formattedMessage)
            .contains("\"temporaryDirectoryCleanupsCompleted\":1", "\"temporaryDirectoryFailures\":0")
            .doesNotContain("expiredSessionIds", "temporaryDirectoriesAlreadyAbsent")
    }

    @Test
    fun `directory cleanup failure is counted and keeps per session diagnostics`() {
        val now = Instant.parse("2025-01-01T04:00:00Z")
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = "schedule-123",
            ownerId = 42L,
            expiresAt = now.minusSeconds(60)
        )
        val attachmentRepository = mock<AttachmentRepository>()
        val sessionRepository = mock<AttachmentUploadSessionRepository>()
        val attachmentService = mock<AttachmentService>()
        val pathResolver = mock<StoragePathResolver>()
        val fileSystemService = mock<FileSystemService>()
        val tempDir = Path.of("/tmp/expired-attachment-session-failure")
        whenever(sessionRepository.findAllByExpiresAtBefore(now)).thenReturn(listOf(session))
        whenever(attachmentRepository.findAllByUploadSessionId(session.id)).thenReturn(emptyList())
        whenever(pathResolver.resolveTemporaryDirectory(session.id)).thenReturn(tempDir)
        doThrow(IOException("directory cleanup failed\nprivate detail"))
            .whenever(fileSystemService).deleteDirectory(tempDir)

        val scheduler = AttachmentCleanupScheduler(
            attachmentRepository,
            sessionRepository,
            attachmentService,
            pathResolver,
            fileSystemService,
            Clock.fixed(now, ZoneOffset.UTC)
        )
        val logger = LoggerFactory.getLogger(AttachmentCleanupScheduler::class.java) as LogbackLogger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            scheduler.cleanupExpiredSessions()
        } finally {
            logger.detachAppender(appender)
        }

        val messages = appender.list.map { it.formattedMessage }
        assertThat(messages.single { it.contains("\"event\":\"attachment.upload_session.expired_and_removed\"") })
            .contains("\"id\":\"${session.id}\"", "\"temporaryDirectoryResult\":\"failed\"")
        assertThat(messages.single { it.contains("\"event\":\"attachment.expired_session_cleanup.completed\"") })
            .contains("\"temporaryDirectoryCleanupsCompleted\":0", "\"temporaryDirectoryFailures\":1")
            .doesNotContain("expiredSessionIds")
        val failure = appender.list.single { it.level == Level.ERROR }
        assertThat(failure.formattedMessage)
            .contains("${session.id}", "java.io.IOException", "stackFrames")
            .doesNotContain("private detail")
    }
}
