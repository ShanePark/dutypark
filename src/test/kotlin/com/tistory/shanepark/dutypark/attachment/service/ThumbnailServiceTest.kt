package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import org.mockito.ArgumentCaptor
import org.mockito.kotlin.*
import org.springframework.util.unit.DataSize
import java.awt.Color
import java.awt.image.BufferedImage
import java.nio.file.Files
import java.nio.file.Path
import java.util.*
import javax.imageio.ImageIO

class ThumbnailServiceTest {

    private lateinit var thumbnailService: ThumbnailService
    private lateinit var mockGenerator: ThumbnailGenerator
    private lateinit var storageProperties: StorageProperties
    private lateinit var mockAttachmentRepository: AttachmentRepository
    private lateinit var mockPathResolver: StoragePathResolver
    private lateinit var mockFileSystemService: FileSystemService

    @TempDir
    lateinit var tempDir: Path

    @BeforeEach
    fun setUp() {
        storageProperties = StorageProperties(
            root = "storage",
            maxFileSize = DataSize.ofMegabytes(50),
            blacklistExt = emptyList(),
            thumbnail = StorageProperties.ThumbnailProperties(maxSide = 200),
            sessionExpirationHours = 24
        )

        mockGenerator = mock()
        mockAttachmentRepository = mock()
        mockPathResolver = mock()
        mockFileSystemService = mock()
        thumbnailService = ThumbnailService(
            listOf(mockGenerator),
            storageProperties,
            mockAttachmentRepository,
            mockPathResolver,
            mockFileSystemService
        )
    }

    @Test
    fun `should return true when thumbnail generation succeeds`() {
        val sourcePath = tempDir.resolve("image.png")
        val targetPath = tempDir.resolve("thumb.png")
        val contentType = "image/png"

        whenever(mockGenerator.canGenerate(contentType)).thenReturn(true)

        val result = thumbnailService.generateThumbnail(sourcePath, targetPath, contentType)

        assertThat(result).isTrue()
        verify(mockGenerator).generate(sourcePath, targetPath, 200)
    }

    @Test
    fun `should return false when no generator supports the content type`() {
        val sourcePath = tempDir.resolve("document.pdf")
        val targetPath = tempDir.resolve("thumb.png")
        val contentType = "application/pdf"

        whenever(mockGenerator.canGenerate(contentType)).thenReturn(false)

        val result = thumbnailService.generateThumbnail(sourcePath, targetPath, contentType)

        assertThat(result).isFalse()
    }

    @Test
    fun `should return false when generator throws exception`() {
        val sourcePath = tempDir.resolve("image.png")
        val targetPath = tempDir.resolve("thumb.png")
        val contentType = "image/png"

        whenever(mockGenerator.canGenerate(contentType)).thenReturn(true)
        whenever(mockGenerator.generate(any(), any(), any())).thenThrow(RuntimeException("Generation failed"))

        val result = thumbnailService.generateThumbnail(sourcePath, targetPath, contentType)

        assertThat(result).isFalse()
    }

    @Test
    fun `should check if thumbnail can be generated for content type`() {
        whenever(mockGenerator.canGenerate("image/png")).thenReturn(true)
        whenever(mockGenerator.canGenerate("application/pdf")).thenReturn(false)

        assertThat(thumbnailService.canGenerateThumbnail("image/png")).isTrue()
        assertThat(thumbnailService.canGenerateThumbnail("application/pdf")).isFalse()
    }

    @Test
    fun `should use configured max side from properties`() {
        val sourcePath = tempDir.resolve("image.png")
        val targetPath = tempDir.resolve("thumb.png")
        val contentType = "image/png"

        whenever(mockGenerator.canGenerate(contentType)).thenReturn(true)

        thumbnailService.generateThumbnail(sourcePath, targetPath, contentType)

        verify(mockGenerator).generate(sourcePath, targetPath, 200)
    }

    @Test
    fun `should use first matching generator from multiple generators`() {
        val generator1 = mock<ThumbnailGenerator>()
        val generator2 = mock<ThumbnailGenerator>()

        whenever(generator1.canGenerate("image/png")).thenReturn(false)
        whenever(generator2.canGenerate("image/png")).thenReturn(true)

        val service = ThumbnailService(
            listOf(generator1, generator2),
            storageProperties,
            mockAttachmentRepository,
            mockPathResolver,
            mockFileSystemService
        )

        val sourcePath = tempDir.resolve("image.png")
        val targetPath = tempDir.resolve("thumb.png")

        service.generateThumbnail(sourcePath, targetPath, "image/png")

        verify(generator2).generate(sourcePath, targetPath, 200)
    }

    @Test
    fun `integration test with real ImageThumbnailGenerator`() {
        val realGenerator = ImageThumbnailGenerator()
        val service = ThumbnailService(
            listOf(realGenerator),
            storageProperties,
            mockAttachmentRepository,
            mockPathResolver,
            mockFileSystemService
        )

        val sourceImage = createTestImage(400, 300)
        val sourcePath = tempDir.resolve("real-image.png")
        ImageIO.write(sourceImage, "png", sourcePath.toFile())

        val targetPath = tempDir.resolve("real-thumb.png")

        val result = service.generateThumbnail(sourcePath, targetPath, "image/png")

        assertThat(result).isTrue()
        assertThat(Files.exists(targetPath)).isTrue()

        val thumbnail = ImageIO.read(targetPath.toFile())
        assertThat(thumbnail.width).isLessThanOrEqualTo(200)
        assertThat(thumbnail.height).isLessThanOrEqualTo(200)
    }

    @Test
    fun `generateThumbnailAsync should update attachment to COMPLETED when generation succeeds`() {
        val attachmentId = UUID.randomUUID()
        val filePath = tempDir.resolve("test.png")
        val thumbnailPath = tempDir.resolve("thumb-test.png")

        Files.write(filePath, "test".toByteArray())
        Files.write(thumbnailPath, "thumbnail".toByteArray())

        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = "schedule-123",
            uploadSessionId = null,
            originalFilename = "test.png",
            storedFilename = "uuid-test.png",
            contentType = "image/png",
            size = 1024L,
            storagePath = tempDir.toString(),
            createdBy = 1L
        )

        whenever(mockAttachmentRepository.findById(attachmentId)).thenReturn(Optional.of(attachment))
        whenever(mockAttachmentRepository.save(any())).thenReturn(attachment)
        whenever(mockPathResolver.resolveThumbnailPath(filePath, attachment.storedFilename)).thenReturn(thumbnailPath)
        whenever(mockGenerator.canGenerate("image/png")).thenReturn(true)
        whenever(mockFileSystemService.fileExists(thumbnailPath)).thenReturn(true)

        thumbnailService.generateThumbnailAsync(attachmentId, filePath)

        val captor = ArgumentCaptor.forClass(Attachment::class.java)
        verify(mockAttachmentRepository).save(captor.capture())

        val savedAttachment = captor.value
        assertThat(savedAttachment.thumbnailStatus).isEqualTo(ThumbnailStatus.COMPLETED)
        assertThat(savedAttachment.thumbnailFilename).isEqualTo("thumb-test.png")
        assertThat(savedAttachment.thumbnailContentType).isEqualTo("image/png")
        assertThat(savedAttachment.thumbnailSize).isGreaterThan(0)
    }

    @Test
    fun `generateThumbnailAsync should update attachment to FAILED when generation fails`() {
        val attachmentId = UUID.randomUUID()
        val filePath = tempDir.resolve("test.png")
        val thumbnailPath = tempDir.resolve("thumb-test.png")

        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = "schedule-123",
            uploadSessionId = null,
            originalFilename = "test.png",
            storedFilename = "uuid-test.png",
            contentType = "image/png",
            size = 1024L,
            storagePath = tempDir.toString(),
            createdBy = 1L
        )

        whenever(mockAttachmentRepository.findById(attachmentId)).thenReturn(Optional.of(attachment))
        whenever(mockPathResolver.resolveThumbnailPath(filePath, attachment.storedFilename)).thenReturn(thumbnailPath)
        whenever(mockGenerator.canGenerate("image/png")).thenReturn(false)

        thumbnailService.generateThumbnailAsync(attachmentId, filePath)

        val captor = ArgumentCaptor.forClass(Attachment::class.java)
        verify(mockAttachmentRepository).save(captor.capture())

        val savedAttachment = captor.value
        assertThat(savedAttachment.thumbnailStatus).isEqualTo(ThumbnailStatus.FAILED)
    }

    @Test
    fun `generateThumbnailAsync should handle attachment not found gracefully`() {
        val attachmentId = UUID.randomUUID()
        val filePath = tempDir.resolve("test.png")

        whenever(mockAttachmentRepository.findById(attachmentId)).thenReturn(Optional.empty())

        thumbnailService.generateThumbnailAsync(attachmentId, filePath)

        verify(mockAttachmentRepository, never()).save(any())
    }

    @Test
    fun `generateThumbnailAsync should update to FAILED when exception occurs`() {
        val attachmentId = UUID.randomUUID()
        val filePath = tempDir.resolve("test.png")

        val attachment = Attachment(
            contextType = AttachmentContextType.SCHEDULE,
            contextId = "schedule-123",
            uploadSessionId = null,
            originalFilename = "test.png",
            storedFilename = "uuid-test.png",
            contentType = "image/png",
            size = 1024L,
            storagePath = tempDir.toString(),
            createdBy = 1L
        )

        whenever(mockAttachmentRepository.findById(attachmentId)).thenReturn(Optional.of(attachment))
        whenever(mockPathResolver.resolveThumbnailPath(any(), any())).thenThrow(RuntimeException("Storage error"))

        thumbnailService.generateThumbnailAsync(attachmentId, filePath)

        verify(mockAttachmentRepository, times(2)).findById(attachmentId)
        val captor = ArgumentCaptor.forClass(Attachment::class.java)
        verify(mockAttachmentRepository).save(captor.capture())

        val savedAttachment = captor.value
        assertThat(savedAttachment.thumbnailStatus).isEqualTo(ThumbnailStatus.FAILED)
    }

    private fun createTestImage(width: Int, height: Int): BufferedImage {
        val image = BufferedImage(width, height, BufferedImage.TYPE_INT_RGB)
        val graphics = image.createGraphics()
        graphics.color = Color.BLUE
        graphics.fillRect(0, 0, width, height)
        graphics.dispose()
        return image
    }
}
