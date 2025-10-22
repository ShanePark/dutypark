package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.common.config.logger
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import java.nio.file.Files
import java.nio.file.Path
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset

private val FIXED_NOW: Instant = Instant.parse("2025-01-01T04:00:00Z")

@Import(AttachmentCleanupIntegrationTest.FixedClockConfig::class)
class AttachmentCleanupIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var cleanupScheduler: AttachmentCleanupScheduler

    @Autowired
    lateinit var sessionRepository: AttachmentUploadSessionRepository

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Autowired
    lateinit var pathResolver: StoragePathResolver

    @Autowired
    lateinit var fileSystemService: FileSystemService

    private val log = logger()

    private val pathsToCleanup: MutableSet<Path> = mutableSetOf()

    @AfterEach
    fun tearDownDirectories() {
        pathsToCleanup.forEach { path ->
            try {
                fileSystemService.deleteDirectory(path)
            } catch (ex: Exception) {
                log.warn("Failed to delete test directory {}: {}", path, ex.message)
            }
        }
        pathsToCleanup.clear()
    }

    @Test
    fun `cleanup job removes expired sessions without touching active ones`() {
        val member = TestData.member

        val expiredSession = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member.id!!,
                expiresAt = FIXED_NOW.minusSeconds(3600)
            )
        )

        val expiredSessionDir = pathResolver.resolveTemporaryDirectory(expiredSession.id)
        Files.createDirectories(expiredSessionDir)
        pathsToCleanup.add(expiredSessionDir)

        val expiredAttachment = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                uploadSessionId = expiredSession.id,
                originalFilename = "expired.txt",
                storedFilename = "expired-${expiredSession.id}.txt",
                contentType = "text/plain",
                size = 42,
                storagePath = expiredSessionDir.toString(),
                createdBy = member.id!!,
                orderIndex = 0,
                thumbnailFilename = "thumb-expired-${expiredSession.id}.png",
                thumbnailContentType = "image/png",
                thumbnailSize = 21
            )
        )

        Files.writeString(expiredSessionDir.resolve(expiredAttachment.storedFilename), "expired session file")
        Files.writeString(expiredSessionDir.resolve(expiredAttachment.thumbnailFilename!!), "expired thumbnail")

        val activeSession = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member.id!!,
                expiresAt = FIXED_NOW.plusSeconds(3600)
            )
        )

        val activeSessionDir = pathResolver.resolveTemporaryDirectory(activeSession.id)
        Files.createDirectories(activeSessionDir)
        pathsToCleanup.add(activeSessionDir)

        val activeAttachment = attachmentRepository.save(
            Attachment(
                contextType = AttachmentContextType.SCHEDULE,
                contextId = null,
                uploadSessionId = activeSession.id,
                originalFilename = "active.txt",
                storedFilename = "active-${activeSession.id}.txt",
                contentType = "text/plain",
                size = 24,
                storagePath = activeSessionDir.toString(),
                createdBy = member.id!!,
                orderIndex = 0
            )
        )

        Files.writeString(activeSessionDir.resolve(activeAttachment.storedFilename), "active session file")

        em.flush()
        em.clear()

        assertThat(sessionRepository.findById(expiredSession.id)).isPresent
        assertThat(attachmentRepository.findById(expiredAttachment.id)).isPresent
        assertThat(Files.exists(expiredSessionDir)).isTrue
        assertThat(Files.exists(activeSessionDir)).isTrue

        cleanupScheduler.cleanupExpiredSessions()
        em.flush()
        em.clear()

        assertThat(sessionRepository.findById(expiredSession.id)).isEmpty
        assertThat(attachmentRepository.findById(expiredAttachment.id)).isEmpty
        assertThat(Files.exists(expiredSessionDir)).isFalse
        assertThat(Files.exists(expiredSessionDir.resolve(expiredAttachment.storedFilename))).isFalse

        assertThat(sessionRepository.findById(activeSession.id)).isPresent
        assertThat(attachmentRepository.findById(activeAttachment.id)).isPresent
        assertThat(Files.exists(activeSessionDir.resolve(activeAttachment.storedFilename))).isTrue
        assertThat(Files.exists(activeSessionDir)).isTrue
    }

    @TestConfiguration
    class FixedClockConfig {
        @Bean
        @Primary
        fun fixedClock(): Clock {
            return Clock.fixed(FIXED_NOW, ZoneOffset.UTC)
        }
    }
}
