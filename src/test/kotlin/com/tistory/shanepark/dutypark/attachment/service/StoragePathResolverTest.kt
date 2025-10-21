package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.util.unit.DataSize
import java.nio.file.Paths
import java.util.UUID

class StoragePathResolverTest {

    private lateinit var pathResolver: StoragePathResolver
    private lateinit var storageProperties: StorageProperties

    @BeforeEach
    fun setUp() {
        storageProperties = StorageProperties(
            root = "test-storage",
            maxFileSize = DataSize.ofMegabytes(50),
            blacklistExt = emptyList(),
            thumbnail = StorageProperties.ThumbnailProperties(maxSide = 200),
            sessionExpirationHours = 24
        )
        pathResolver = StoragePathResolver(storageProperties)
    }

    @Test
    fun `should resolve temporary directory path`() {
        val sessionId = UUID.randomUUID()

        val path = pathResolver.resolveTemporaryDirectory(sessionId)

        assertThat(path).isEqualTo(Paths.get("test-storage", "_tmp", sessionId.toString()))
    }

    @Test
    fun `should resolve permanent directory path`() {
        val contextId = "schedule-123"

        val path = pathResolver.resolvePermanentDirectory(AttachmentContextType.SCHEDULE, contextId)

        assertThat(path).isEqualTo(Paths.get("test-storage", "SCHEDULE", contextId))
    }

    @Test
    fun `should resolve temporary file path`() {
        val sessionId = UUID.randomUUID()
        val storedFilename = "${UUID.randomUUID()}.png"

        val path = pathResolver.resolveTemporaryFilePath(sessionId, storedFilename)

        assertThat(path).isEqualTo(Paths.get("test-storage", "_tmp", sessionId.toString(), storedFilename))
    }

    @Test
    fun `should resolve permanent file path`() {
        val contextId = "schedule-123"
        val storedFilename = "${UUID.randomUUID()}.png"

        val path = pathResolver.resolvePermanentFilePath(
            AttachmentContextType.SCHEDULE,
            contextId,
            storedFilename
        )

        assertThat(path).isEqualTo(Paths.get("test-storage", "SCHEDULE", contextId, storedFilename))
    }

    @Test
    fun `should resolve thumbnail path with correct naming`() {
        val storedFilename = "${UUID.randomUUID()}.png"
        val filePath = Paths.get("test-storage", "SCHEDULE", "schedule-123", storedFilename)

        val thumbnailPath = pathResolver.resolveThumbnailPath(filePath, storedFilename)

        val expectedFilename = "thumb-${storedFilename.substringBeforeLast('.')}.png"
        assertThat(thumbnailPath).isEqualTo(
            Paths.get("test-storage", "SCHEDULE", "schedule-123", expectedFilename)
        )
    }

    @Test
    fun `should handle filename without extension for thumbnail`() {
        val storedFilename = UUID.randomUUID().toString()
        val filePath = Paths.get("test-storage", "SCHEDULE", "schedule-123", storedFilename)

        val thumbnailPath = pathResolver.resolveThumbnailPath(filePath, storedFilename)

        assertThat(thumbnailPath.fileName.toString()).isEqualTo("thumb-$storedFilename.png")
    }

    @Test
    fun `should get storage root path`() {
        val root = pathResolver.getStorageRoot()

        assertThat(root).isEqualTo(Paths.get("test-storage"))
    }
}
