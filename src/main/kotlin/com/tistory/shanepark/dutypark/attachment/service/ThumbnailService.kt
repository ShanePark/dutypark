package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional
import java.nio.file.Path
import java.util.*

@Service
class ThumbnailService(
    private val thumbnailGenerators: List<ThumbnailGenerator>,
    private val storageProperties: StorageProperties,
    private val attachmentRepository: AttachmentRepository,
    private val pathResolver: StoragePathResolver,
    private val fileSystemService: FileSystemService
) {
    private val log = logger()

    fun canGenerateThumbnail(contentType: String): Boolean {
        return thumbnailGenerators.any { it.canGenerate(contentType) }
    }

    @Async("thumbnailExecutor")
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    fun generateThumbnailAsync(attachmentId: UUID, filePath: Path) {
        try {
            val attachment = attachmentRepository.findById(attachmentId).orElse(null)
            if (attachment == null) {
                log.warn("Attachment not found for thumbnail generation: {}", attachmentId)
                return
            }

            val thumbnailPath = pathResolver.resolveThumbnailPath(filePath, attachment.storedFilename)
            val success = generateThumbnail(filePath, thumbnailPath, attachment.contentType)

            if (success && fileSystemService.fileExists(thumbnailPath)) {
                attachment.thumbnailFilename = thumbnailPath.fileName.toString()
                attachment.thumbnailContentType = "image/png"
                attachment.thumbnailSize = thumbnailPath.toFile().length()
                attachment.thumbnailStatus = ThumbnailStatus.COMPLETED

                attachmentRepository.save(attachment)
                log.info("Thumbnail generated successfully for attachment: {}", attachment.storedFilename)
            } else {
                attachment.thumbnailStatus = ThumbnailStatus.FAILED
                attachmentRepository.save(attachment)
                log.warn("Thumbnail generation failed for attachment: {}", attachment.storedFilename)
            }
        } catch (e: Exception) {
            log.error("Thumbnail generation error for attachment: {}", attachmentId, e)
            val attachment = attachmentRepository.findById(attachmentId).orElse(null)
            if (attachment != null) {
                attachment.thumbnailStatus = ThumbnailStatus.FAILED
                attachmentRepository.save(attachment)
            }
        }
    }

    fun generateThumbnail(sourcePath: Path, targetPath: Path, contentType: String): Boolean {
        val generator = thumbnailGenerators.firstOrNull { it.canGenerate(contentType) }

        if (generator == null) {
            log.debug("No thumbnail generator found for content type: {}", contentType)
            return false
        }

        return try {
            generator.generate(sourcePath, targetPath, storageProperties.thumbnail.maxSide)
            true
        } catch (e: Exception) {
            log.error(
                "Thumbnail generation failed for {} with content type {}: {}",
                sourcePath.fileName, contentType, e.message
            )
            false
        }
    }
}
