package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.util.*

@Service
@Transactional
class AttachmentService(
    private val attachmentRepository: AttachmentRepository,
    private val validationService: AttachmentValidationService,
    private val pathResolver: StoragePathResolver,
    private val fileSystemService: FileSystemService,
    private val thumbnailService: ThumbnailService
) {
    private val log = logger()

    fun uploadFile(
        sessionId: UUID,
        file: MultipartFile,
        contextType: AttachmentContextType,
        createdBy: Long
    ): Attachment {
        validationService.validateFile(file)

        val originalFilename = file.originalFilename ?: "unknown"
        val storedFilename = generateStoredFilename(originalFilename)
        val temporaryFilePath = pathResolver.resolveTemporaryFilePath(sessionId, storedFilename)

        val existingAttachments = attachmentRepository.findAllByUploadSessionId(sessionId)
        val nextOrderIndex = existingAttachments.size

        try {
            fileSystemService.writeFile(file, temporaryFilePath)

            val attachment = Attachment(
                contextType = contextType,
                contextId = null,
                uploadSessionId = sessionId,
                originalFilename = originalFilename,
                storedFilename = storedFilename,
                contentType = file.contentType ?: "application/octet-stream",
                size = file.size,
                storagePath = pathResolver.resolveTemporaryDirectory(sessionId).toString(),
                createdBy = createdBy,
                orderIndex = nextOrderIndex
            )

            if (thumbnailService.canGenerateThumbnail(attachment.contentType)) {
                generateThumbnailForAttachment(temporaryFilePath, attachment)
            }

            val savedAttachment = attachmentRepository.save(attachment)

            log.info(
                "File uploaded successfully: sessionId={}, filename={}, size={}, orderIndex={}",
                sessionId, originalFilename, file.size, nextOrderIndex
            )

            return savedAttachment
        } catch (e: Exception) {
            log.error("Failed to upload file: sessionId={}, filename={}", sessionId, originalFilename, e)
            fileSystemService.deleteFile(temporaryFilePath)
            throw e
        }
    }

    private fun generateStoredFilename(originalFilename: String): String {
        val extension = originalFilename.substringAfterLast('.', "")
        val uuid = UUID.randomUUID()
        return if (extension.isNotEmpty()) {
            "$uuid.$extension"
        } else {
            uuid.toString()
        }
    }

    private fun generateThumbnailForAttachment(filePath: java.nio.file.Path, attachment: Attachment) {
        val thumbnailPath = pathResolver.resolveThumbnailPath(filePath, attachment.storedFilename)

        val success = thumbnailService.generateThumbnail(filePath, thumbnailPath, attachment.contentType)

        if (success && fileSystemService.fileExists(thumbnailPath)) {
            attachment.thumbnailFilename = thumbnailPath.fileName.toString()
            attachment.thumbnailContentType = "image/png"
            attachment.thumbnailSize = thumbnailPath.toFile().length()

            log.info("Thumbnail generated for attachment: {}", attachment.storedFilename)
        }
    }
}
