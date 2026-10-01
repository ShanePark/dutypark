package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.event.AttachmentUploadedEvent
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import org.springframework.scheduling.annotation.Async
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.transaction.event.TransactionPhase
import org.springframework.transaction.event.TransactionalEventListener
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
    private val systemActor = AuditActor(id = null, name = "system:thumbnail-generation")

    fun canGenerateThumbnail(contentType: String): Boolean {
        return thumbnailGenerators.any { it.canGenerate(contentType) }
    }

    @TransactionalEventListener(phase = TransactionPhase.AFTER_COMMIT)
    @Async("thumbnailExecutor")
    fun handleAttachmentUploaded(event: AttachmentUploadedEvent) {
        generateThumbnailAsync(event.attachmentId, event.filePath)
    }

    @Transactional
    fun generateThumbnailAsync(attachmentId: UUID, filePath: Path) {
        var failureContext: Map<String, Any?> = mapOf(
            "type" to "Attachment",
            "id" to attachmentId,
            "actor" to systemActor,
            "sourcePath" to filePath.toString()
        )
        try {
            val attachment = attachmentRepository.findById(attachmentId).orElse(null)
            if (attachment == null) {
                log.warn(
                    "Thumbnail task referenced a missing attachment: {}",
                    auditContext(
                        mapOf(
                            "actor" to systemActor,
                            "attachmentId" to attachmentId,
                            "sourcePath" to filePath.toString()
                        )
                    )
                )
                return
            }

            val target = thumbnailAuditTarget(attachment)
            failureContext = target + mapOf(
                "actor" to systemActor,
                "sourcePath" to filePath.toString()
            )
            val before = thumbnailSnapshot(attachment)

            val thumbnailPath = pathResolver.resolveThumbnailPath(filePath, attachment.storedFilename)
            val success = generateThumbnail(filePath, thumbnailPath, attachment.contentType)

            if (success && fileSystemService.fileExists(thumbnailPath)) {
                attachment.thumbnailFilename = thumbnailPath.fileName.toString()
                attachment.thumbnailContentType = "image/png"
                attachment.thumbnailSize = thumbnailPath.toFile().length()
                attachment.thumbnailStatus = ThumbnailStatus.COMPLETED
                attachmentRepository.save(attachment)
                log.auditChangeAfterCommit(
                    event = "attachment.thumbnail.completed",
                    actor = systemActor,
                    target = target,
                    before = before,
                    after = thumbnailSnapshot(attachment)
                )
            } else {
                attachment.thumbnailStatus = ThumbnailStatus.FAILED
                attachmentRepository.save(attachment)
                log.auditChangeAfterCommit(
                    event = "attachment.thumbnail.failed",
                    actor = systemActor,
                    target = target,
                    before = before,
                    after = thumbnailSnapshot(attachment)
                )
                log.error(
                    "Thumbnail generation produced no usable output: {}",
                    auditContext(
                        target + mapOf(
                            "actor" to systemActor,
                            "contentType" to attachment.contentType,
                            "sourcePath" to filePath.toString(),
                            "thumbnailPath" to thumbnailPath.toString(),
                            "reason" to if (success) "thumbnail_file_missing" else "generation_failed"
                        )
                    )
                )
            }
        } catch (e: Exception) {
            log.error(
                "Thumbnail generation task failed: {}",
                auditContext(failureContext + e.toAttachmentLogDiagnostics())
            )
            val attachment = attachmentRepository.findById(attachmentId).orElse(null)
            if (attachment != null) {
                val before = thumbnailSnapshot(attachment)
                attachment.thumbnailStatus = ThumbnailStatus.FAILED
                attachmentRepository.save(attachment)
                log.auditChangeAfterCommit(
                    event = "attachment.thumbnail.failed",
                    actor = systemActor,
                    target = thumbnailAuditTarget(attachment),
                    before = before,
                    after = thumbnailSnapshot(attachment)
                )
            }
        }
    }

    fun generateThumbnail(sourcePath: Path, targetPath: Path, contentType: String): Boolean {
        val generator = thumbnailGenerators.firstOrNull { it.canGenerate(contentType) }
        if (generator == null) {
            log.warn(
                "No thumbnail generator supports the attachment content type: {}",
                auditContext(
                    mapOf(
                        "contentType" to contentType,
                        "sourcePath" to sourcePath.toString(),
                        "targetPath" to targetPath.toString()
                    )
                )
            )
            return false
        }

        return try {
            generator.generate(sourcePath, targetPath, storageProperties.thumbnail.maxSide)
            true
        } catch (e: Exception) {
            log.error(
                "Thumbnail generator failed: {}",
                auditContext(
                    mapOf(
                        "sourcePath" to sourcePath.toString(),
                        "targetPath" to targetPath.toString(),
                        "contentType" to contentType,
                        "maxSide" to storageProperties.thumbnail.maxSide
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
            false
        }
    }

    private fun thumbnailAuditTarget(attachment: Attachment) =
        mapOf(
            "type" to "Attachment",
            "id" to attachment.id,
            "contextType" to attachment.contextType,
            "contextId" to attachment.contextId,
            "uploadSessionId" to attachment.uploadSessionId,
            "ownerId" to attachment.createdBy,
            "ownerName" to null,
            "filename" to attachment.originalFilename,
            "contentType" to attachment.contentType
        )

    private fun thumbnailSnapshot(attachment: Attachment) =
        mapOf(
            "thumbnailStatus" to attachment.thumbnailStatus,
            "thumbnailFilename" to attachment.thumbnailFilename,
            "thumbnailContentType" to attachment.thumbnailContentType,
            "thumbnailSize" to attachment.thumbnailSize
        )
}
