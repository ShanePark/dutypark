package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.enums.ThumbnailStatus
import com.tistory.shanepark.dutypark.attachment.domain.event.AttachmentUploadedEvent
import com.tistory.shanepark.dutypark.attachment.dto.AttachmentDto
import com.tistory.shanepark.dutypark.attachment.dto.FinalizeSessionRequest
import com.tistory.shanepark.dutypark.attachment.dto.ReorderAttachmentsRequest
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.context.ApplicationEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.io.IOException
import java.nio.file.Files
import java.nio.file.StandardCopyOption
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
    private val sessionService: AttachmentUploadSessionService,
    private val eventPublisher: ApplicationEventPublisher
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
                eventPublisher.publishEvent(
                    AttachmentUploadedEvent(
                        attachmentId = savedAttachment.id,
                        filePath = temporaryFilePath
                    )
                )
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

        deleteAttachment(attachment)
    }

    fun deleteAttachment(attachment: Attachment) {
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
        log.info("Deleted attachment: id={}, filename={}", attachment.id, attachment.originalFilename)
    }

    fun finalizeSession(
        loginMember: LoginMember,
        sessionId: UUID,
        request: FinalizeSessionRequest
    ) {
        val session = sessionService.findById(sessionId)
            ?: throw IllegalArgumentException("Upload session not found: $sessionId")

        permissionEvaluator.checkSessionOwnership(loginMember, session)

        if (session.targetContextId != null && session.targetContextId != request.contextId) {
            throw IllegalStateException("Context ID mismatch: expected ${session.targetContextId}, got ${request.contextId}")
        }

        val attachments = attachmentRepository.findAllByUploadSessionId(sessionId)
        if (attachments.isEmpty()) {
            sessionService.deleteSession(sessionId)
            log.info("Finalized empty session: sessionId={}", sessionId)
            return
        }

        val tempDir = pathResolver.resolveTemporaryDirectory(sessionId)
        val finalDir = pathResolver.resolveContextDirectory(session.contextType, request.contextId)

        Files.createDirectories(finalDir)

        try {
            attachments.forEach { attachment ->
                val tempFilePath = tempDir.resolve(attachment.storedFilename)
                val finalFilePath = finalDir.resolve(attachment.storedFilename)

                if (!Files.exists(tempFilePath)) {
                    throw IOException("Source file not found: ${attachment.storedFilename}")
                }

                Files.move(
                    tempFilePath,
                    finalFilePath,
                    StandardCopyOption.ATOMIC_MOVE,
                    StandardCopyOption.REPLACE_EXISTING
                )

                val thumbnailFilename = attachment.thumbnailFilename
                if (thumbnailFilename != null) {
                    val tempThumbnailPath = tempDir.resolve(thumbnailFilename)
                    val finalThumbnailPath = finalDir.resolve(thumbnailFilename)
                    if (Files.exists(tempThumbnailPath)) {
                        Files.move(
                            tempThumbnailPath,
                            finalThumbnailPath,
                            StandardCopyOption.ATOMIC_MOVE,
                            StandardCopyOption.REPLACE_EXISTING
                        )
                    }
                }

                attachment.contextId = request.contextId
                attachment.uploadSessionId = null
                attachment.storagePath = finalDir.toString()
            }

            val orderedIds = request.orderedAttachmentIds
            orderedIds.forEachIndexed { index, attachmentId ->
                val attachment = attachments.find { it.id == attachmentId }
                attachment?.orderIndex = index
            }

            val unorderedAttachments = attachments.filter { it.id !in orderedIds }
            unorderedAttachments.forEachIndexed { index, attachment ->
                attachment.orderIndex = orderedIds.size + index
            }

            attachmentRepository.saveAll(attachments)

            if (Files.exists(tempDir)) {
                fileSystemService.deleteDirectory(tempDir)
            }

            sessionService.deleteSession(sessionId)

            log.info(
                "Finalized session: sessionId={}, contextId={}, attachmentCount={}",
                sessionId,
                request.contextId,
                attachments.size
            )
        } catch (e: Exception) {
            log.error("Failed to finalize session: sessionId={}, error={}", sessionId, e.message, e)
            throw IllegalStateException("Failed to finalize session", e)
        }
    }

    fun reorderAttachments(
        loginMember: LoginMember,
        request: ReorderAttachmentsRequest
    ) {
        val attachments = attachmentRepository.findAllByContextTypeAndContextId(
            request.contextType,
            request.contextId
        )

        if (attachments.isEmpty()) {
            log.warn(
                "No attachments found for reordering: contextType={}, contextId={}",
                request.contextType,
                request.contextId
            )
            return
        }

        val firstAttachment = attachments.first()
        permissionEvaluator.checkWritePermission(loginMember, firstAttachment)

        request.orderedAttachmentIds.forEachIndexed { index, attachmentId ->
            val attachment = attachments.find { it.id == attachmentId }
            attachment?.orderIndex = index
        }

        val unorderedAttachments = attachments.filter { it.id !in request.orderedAttachmentIds }
        unorderedAttachments.forEachIndexed { index, attachment ->
            attachment.orderIndex = request.orderedAttachmentIds.size + index
        }

        attachmentRepository.saveAll(attachments)

        log.info(
            "Reordered attachments: contextType={}, contextId={}, count={}",
            request.contextType,
            request.contextId,
            attachments.size
        )
    }

    fun listAttachments(
        loginMember: LoginMember?,
        contextType: AttachmentContextType,
        contextId: String
    ): List<AttachmentDto> {
        val attachments =
            attachmentRepository.findAllByContextTypeAndContextIdOrderByOrderIndexAsc(contextType, contextId)

        if (attachments.isEmpty()) {
            return emptyList()
        }

        val firstAttachment = attachments.first()
        permissionEvaluator.checkReadPermission(loginMember, firstAttachment)

        return attachments.map { AttachmentDto.from(it) }
    }

    fun finalizeSessionForSchedule(loginMember: LoginMember, sessionId: UUID, scheduleId: String) {
        val request = FinalizeSessionRequest(
            contextId = scheduleId,
            orderedAttachmentIds = emptyList()
        )
        finalizeSession(loginMember, sessionId, request)
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
