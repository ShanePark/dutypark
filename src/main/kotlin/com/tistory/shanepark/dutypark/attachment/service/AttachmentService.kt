package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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
    private val thumbnailService: ThumbnailService,
    private val permissionEvaluator: AttachmentPermissionEvaluator,
    private val sessionService: AttachmentUploadSessionService
) {
    private val log = logger()

    fun uploadFile(
        loginMember: LoginMember,
        sessionId: UUID,
        file: MultipartFile
    ): Attachment {
        val session = sessionService.findById(sessionId)
            ?: throw IllegalArgumentException("Upload session not found: $sessionId")

        permissionEvaluator.checkSessionOwnership(loginMember, session)

        validationService.validateFile(file)

        val originalFilename = file.originalFilename ?: "unknown"
        val storedFilename = generateStoredFilename(originalFilename)
        val temporaryFilePath = pathResolver.resolveTemporaryFilePath(sessionId, storedFilename)

        val existingAttachments = attachmentRepository.findAllByUploadSessionId(sessionId)
        val nextOrderIndex = existingAttachments.size

        try {
            fileSystemService.writeFile(file, temporaryFilePath)

            val attachment = Attachment(
                contextType = session.contextType,
                contextId = null,
                uploadSessionId = sessionId,
                originalFilename = originalFilename,
                storedFilename = storedFilename,
                contentType = file.contentType ?: "application/octet-stream",
                size = file.size,
                storagePath = pathResolver.resolveTemporaryDirectory(sessionId).toString(),
                createdBy = loginMember.id,
                orderIndex = nextOrderIndex
            )

            if (thumbnailService.canGenerateThumbnail(attachment.contentType)) {
                attachment.thumbnailStatus = ThumbnailStatus.PENDING
            }

            val savedAttachment = attachmentRepository.save(attachment)

            if (attachment.thumbnailStatus == ThumbnailStatus.PENDING) {
                thumbnailService.generateThumbnailAsync(savedAttachment.id, temporaryFilePath)
            }

            log.info(
                "File uploaded successfully: sessionId={}, filename={}, size={}, orderIndex={}",
                sessionId,
                originalFilename,
                file.size,
                nextOrderIndex
            )

            return savedAttachment
        } catch (e: Exception) {
            log.error("Failed to upload file: sessionId={}, filename={}", sessionId, originalFilename, e)
            fileSystemService.deleteFile(temporaryFilePath)
            throw e
        }
    }

    fun findById(loginMember: LoginMember?, attachmentId: UUID): Attachment? {
        val attachment = attachmentRepository.findById(attachmentId).orElseThrow()
        val sessionId = attachment.uploadSessionId

        if (sessionId != null) {
            if (loginMember == null) {
                throw AuthException("Authentication required to view session attachments")
            }
            val session = sessionService.findById(sessionId)
                ?: throw IllegalStateException("Session not found for attachment: $attachmentId")
            permissionEvaluator.checkSessionOwnership(loginMember, session)
        } else {
            permissionEvaluator.checkReadPermission(loginMember, attachment)
        }

        return attachment
    }

    fun deleteAttachment(loginMember: LoginMember, attachmentId: UUID) {
        val attachment = attachmentRepository.findById(attachmentId).orElseThrow {
            IllegalArgumentException("Attachment not found: $attachmentId")
        }

        val sessionId = attachment.uploadSessionId
        if (sessionId != null) {
            val session = sessionService.findById(sessionId)
                ?: throw IllegalStateException("Session not found for attachment: $attachmentId")
            permissionEvaluator.checkSessionOwnership(loginMember, session)
        } else {
            permissionEvaluator.checkWritePermission(loginMember, attachment)
        }

        val filePath = pathResolver.resolveFilePath(
            attachment.contextType,
            attachment.contextId,
            attachment.uploadSessionId,
            attachment.storedFilename
        )

        fileSystemService.deleteFile(filePath)

        val thumbnailFilename = attachment.thumbnailFilename
        if (thumbnailFilename != null) {
            val thumbnailPath = pathResolver.resolveThumbnailPath(
                attachment.contextType,
                attachment.contextId,
                attachment.uploadSessionId,
                thumbnailFilename
            )
            fileSystemService.deleteFile(thumbnailPath)
        }

        attachmentRepository.delete(attachment)

        log.info("Deleted attachment: id={}, filename={}", attachmentId, attachment.originalFilename)
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
}
