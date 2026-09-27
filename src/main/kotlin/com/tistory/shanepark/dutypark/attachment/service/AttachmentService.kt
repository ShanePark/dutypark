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
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
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

            log.auditEventAfterCommit(
                event = "attachment.uploaded",
                actor = loginMember.toAuditActor(),
                target = attachmentAuditTarget(savedAttachment, loginMember.toAuditActor()),
                details = mapOf(
                    "originalFilename" to savedAttachment.originalFilename,
                    "storedFilename" to savedAttachment.storedFilename,
                    "contentType" to savedAttachment.contentType,
                    "size" to savedAttachment.size,
                    "orderIndex" to savedAttachment.orderIndex,
                    "thumbnailStatus" to savedAttachment.thumbnailStatus
                )
            )

            return savedAttachment
        } catch (e: Exception) {
            log.error(
                "Failed to upload attachment: {}",
                auditContext(
                    mapOf(
                        "actorId" to loginMember.id,
                        "actorName" to loginMember.name,
                        "ownerId" to session.ownerId,
                        "ownerName" to ownerName(session.ownerId, loginMember.toAuditActor()),
                        "sessionId" to sessionId,
                        "contextType" to session.contextType,
                        "contextId" to session.targetContextId,
                        "filename" to originalFilename,
                        "size" to file.size
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
            fileSystemService.deleteFile(temporaryFilePath)
            throw e
        }
    }

    fun findById(loginMember: LoginMember?, attachmentId: UUID): Attachment {
        val attachment = attachmentRepository.findById(attachmentId).orElseThrow()
        val sessionId = attachment.uploadSessionId

        if (sessionId != null) {
            if (loginMember == null) {
                throw AuthException("attachment.session.auth.required")
            }
            val session = sessionService.findById(sessionId)
                ?: throw BadRequestException("attachment.session.notFound")
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
                ?: throw BadRequestException("attachment.session.notFound")
            permissionEvaluator.checkSessionOwnership(loginMember, session)
        } else {
            permissionEvaluator.checkWritePermission(loginMember, attachment)
        }

        deleteAttachment(attachment, actor = loginMember.toAuditActor(), reason = "direct_request")
    }

    fun deleteAttachment(
        attachment: Attachment,
        actor: AuditActor? = null,
        reason: String = "unspecified"
    ) {
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
        log.auditEventAfterCommit(
            event = "attachment.deleted",
            actor = actor,
            target = attachmentAuditTarget(attachment, actor),
            details = mapOf(
                "originalFilename" to attachment.originalFilename,
                "storedFilename" to attachment.storedFilename,
                "size" to attachment.size,
                "reason" to reason
            )
        )
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
            throw BadRequestException("attachment.session.contextMismatch")
        }

        val allAttachments = attachmentRepository.findAllByUploadSessionId(sessionId)
        if (allAttachments.isEmpty()) {
            sessionService.deleteSession(sessionId)
            log.auditEventAfterCommit(
                event = "attachment.upload_session.finalized_empty",
                actor = loginMember.toAuditActor(),
                target = sessionAuditTarget(sessionId, session.contextType, session.targetContextId, session.ownerId, loginMember.toAuditActor()),
                details = mapOf("attachmentCount" to 0, "deletedAttachmentCount" to 0)
            )
            return
        }

        val orderedIds = request.orderedAttachmentIds
        val attachmentsToKeep = if (orderedIds.isEmpty()) {
            allAttachments
        } else {
            allAttachments.filter { it.id in orderedIds }
        }
        val attachmentsToDelete = allAttachments.filter { it.id !in orderedIds && orderedIds.isNotEmpty() }
        val beforeStates = attachmentsToKeep.associate { attachment ->
            attachment.id to mapOf(
                "contextId" to attachment.contextId,
                "uploadSessionId" to attachment.uploadSessionId,
                "orderIndex" to attachment.orderIndex
            )
        }

        val tempDir = pathResolver.resolveTemporaryDirectory(sessionId)
        val finalDir = pathResolver.resolveContextDirectory(session.contextType, request.contextId)

        Files.createDirectories(finalDir)

        try {
            attachmentsToKeep.forEach { attachment ->
                val finalFilePath = moveAttachmentToFinalLocation(attachment, tempDir, finalDir, request.contextId)

                if (attachment.thumbnailStatus == ThumbnailStatus.PENDING) {
                    eventPublisher.publishEvent(
                        AttachmentUploadedEvent(
                            attachmentId = attachment.id,
                            filePath = finalFilePath
                        )
                    )
                }
            }

            updateAttachmentOrdering(attachmentsToKeep, orderedIds)
            attachmentRepository.saveAll(attachmentsToKeep)

            attachmentsToDelete.forEach { deleteTempAttachment(it, tempDir, loginMember.toAuditActor()) }

            if (Files.exists(tempDir)) {
                fileSystemService.deleteDirectory(tempDir)
            }

            sessionService.deleteSession(sessionId)

            attachmentsToKeep.forEach { attachment ->
                log.auditChangeAfterCommit(
                    event = "attachment.finalized",
                    actor = loginMember.toAuditActor(),
                    target = attachmentAuditTarget(attachment, loginMember.toAuditActor()),
                    before = beforeStates.getValue(attachment.id),
                    after = mapOf(
                        "contextId" to attachment.contextId,
                        "uploadSessionId" to attachment.uploadSessionId,
                        "orderIndex" to attachment.orderIndex
                    )
                )
            }
            log.auditEventAfterCommit(
                event = "attachment.upload_session.finalized",
                actor = loginMember.toAuditActor(),
                target = sessionAuditTarget(sessionId, session.contextType, request.contextId, session.ownerId, loginMember.toAuditActor()),
                details = mapOf(
                    "finalizedAttachmentIds" to attachmentsToKeep.map { it.id },
                    "deletedAttachmentIds" to attachmentsToDelete.map { it.id },
                    "finalizedAttachmentCount" to attachmentsToKeep.size,
                    "deletedAttachmentCount" to attachmentsToDelete.size
                )
            )
        } catch (e: Exception) {
            log.error(
                "Failed to finalize attachment upload session: {}",
                auditContext(
                    mapOf(
                        "actorId" to loginMember.id,
                        "actorName" to loginMember.name,
                        "ownerId" to session.ownerId,
                        "ownerName" to ownerName(session.ownerId, loginMember.toAuditActor()),
                        "sessionId" to sessionId,
                        "contextType" to session.contextType,
                        "contextId" to request.contextId,
                        "attachmentCount" to allAttachments.size,
                        "deletedAttachmentCount" to attachmentsToDelete.size
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
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
                "Attachment reorder had no matching attachments: {}",
                auditContext(
                    mapOf(
                        "actorId" to loginMember.id,
                        "actorName" to loginMember.name,
                        "contextType" to request.contextType,
                        "contextId" to request.contextId,
                        "requestedAttachmentIds" to request.orderedAttachmentIds
                    )
                )
            )
            return
        }

        val firstAttachment = attachments.first()
        permissionEvaluator.checkWritePermission(loginMember, firstAttachment)

        val beforeOrder = attachments.associate { it.id to it.orderIndex }
        updateAttachmentOrdering(attachments, request.orderedAttachmentIds)
        attachmentRepository.saveAll(attachments)

        attachments.forEach { attachment ->
            log.auditChangeAfterCommit(
                event = "attachment.order_changed",
                actor = loginMember.toAuditActor(),
                target = attachmentAuditTarget(attachment, loginMember.toAuditActor()),
                before = mapOf("orderIndex" to beforeOrder.getValue(attachment.id)),
                after = mapOf("orderIndex" to attachment.orderIndex)
            )
        }
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

    fun discardSession(
        loginMember: LoginMember,
        sessionId: UUID
    ) {
        val session = sessionService.findById(sessionId)
            ?: throw IllegalArgumentException("Upload session not found: $sessionId")

        permissionEvaluator.checkSessionOwnership(loginMember, session)

        val sessionAttachments = attachmentRepository.findAllByUploadSessionId(sessionId)
        sessionAttachments.forEach {
            deleteAttachment(it, actor = loginMember.toAuditActor(), reason = "session_discard")
        }

        val tempDir = pathResolver.resolveTemporaryDirectory(sessionId)
        if (Files.exists(tempDir)) {
            fileSystemService.deleteDirectory(tempDir)
        }

        sessionService.deleteSession(sessionId)

        log.auditEventAfterCommit(
            event = "attachment.upload_session.discarded",
            actor = loginMember.toAuditActor(),
            target = sessionAuditTarget(sessionId, session.contextType, session.targetContextId, session.ownerId, loginMember.toAuditActor()),
            details = mapOf(
                "deletedAttachmentIds" to sessionAttachments.map { it.id },
                "deletedAttachmentCount" to sessionAttachments.size
            )
        )
    }

    fun synchronizeContextAttachments(
        loginMember: LoginMember,
        contextType: AttachmentContextType,
        contextId: String,
        attachmentSessionId: UUID?,
        orderedAttachmentIds: List<UUID>
    ) {
        val existingAttachments = attachmentRepository.findAllByContextTypeAndContextId(contextType, contextId)

        if (attachmentSessionId == null && orderedAttachmentIds.isEmpty() && existingAttachments.isEmpty()) {
            return
        }

        if (attachmentSessionId != null) {
            val session = sessionService.findById(attachmentSessionId)
                ?: throw IllegalArgumentException("Upload session not found: $attachmentSessionId")

            if (session.contextType != contextType) {
                throw BadRequestException("attachment.session.contextMismatch")
            }

            val sessionAttachments = attachmentRepository.findAllByUploadSessionId(attachmentSessionId)

            if (sessionAttachments.isNotEmpty()) {
                val request = FinalizeSessionRequest(
                    contextId = contextId,
                    orderedAttachmentIds = orderedAttachmentIds
                )
                finalizeSession(loginMember, attachmentSessionId, request)
            } else {
                sessionService.deleteSession(attachmentSessionId)
                log.auditEventAfterCommit(
                    event = "attachment.upload_session.finalized_empty",
                    actor = loginMember.toAuditActor(),
                    target = sessionAuditTarget(
                        attachmentSessionId,
                        session.contextType,
                        session.targetContextId,
                        session.ownerId,
                        loginMember.toAuditActor()
                    ),
                    details = mapOf("attachmentCount" to 0, "deletedAttachmentCount" to 0)
                )
            }
        }

        val attachmentsToDelete = existingAttachments.filter { it.id !in orderedAttachmentIds }
        attachmentsToDelete.forEach { attachment ->
            deleteAttachment(attachment, actor = loginMember.toAuditActor(), reason = "not_in_ordered_attachment_ids")
        }

        if (orderedAttachmentIds.isNotEmpty()) {
            val reorderRequest = ReorderAttachmentsRequest(
                contextType = contextType,
                contextId = contextId,
                orderedAttachmentIds = orderedAttachmentIds
            )
            reorderAttachments(loginMember, reorderRequest)
        }

        val remainingAttachments =
            attachmentRepository.findAllByContextTypeAndContextId(contextType, contextId)
        if (remainingAttachments.isEmpty()) {
            val contextDir = pathResolver.resolveContextDirectory(contextType, contextId)
            fileSystemService.deleteDirectory(contextDir)
            log.info(
                "Deleted empty attachment directory: {}",
                auditContext(
                    mapOf(
                        "actorId" to loginMember.id,
                        "actorName" to loginMember.name,
                        "contextType" to contextType,
                        "contextId" to contextId,
                        "path" to contextDir.toString()
                    )
                )
            )
        }
    }

    fun hasAttachments(
        contextType: AttachmentContextType,
        contextId: String
    ): Boolean {
        return attachmentRepository.existsByContextTypeAndContextId(contextType, contextId)
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

    private fun moveAttachmentToFinalLocation(
        attachment: Attachment,
        tempDir: java.nio.file.Path,
        finalDir: java.nio.file.Path,
        contextId: String
    ): java.nio.file.Path {
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

        attachment.contextId = contextId
        attachment.uploadSessionId = null
        attachment.storagePath = finalDir.toString()

        return finalFilePath
    }

    private fun updateAttachmentOrdering(
        attachments: List<Attachment>,
        orderedIds: List<UUID>
    ) {
        orderedIds.forEachIndexed { index, attachmentId ->
            val attachment = attachments.find { it.id == attachmentId }
            attachment?.orderIndex = index
        }

        val unorderedAttachments = attachments.filter { it.id !in orderedIds }
        unorderedAttachments.forEachIndexed { index, attachment ->
            attachment.orderIndex = orderedIds.size + index
        }
    }

    private fun deleteTempAttachment(
        attachment: Attachment,
        tempDir: java.nio.file.Path,
        actor: AuditActor
    ) {
        val tempFilePath = tempDir.resolve(attachment.storedFilename)
        if (Files.exists(tempFilePath)) {
            Files.delete(tempFilePath)
        }
        val thumbnailFilename = attachment.thumbnailFilename
        if (thumbnailFilename != null) {
            val tempThumbnailPath = tempDir.resolve(thumbnailFilename)
            if (Files.exists(tempThumbnailPath)) {
                Files.delete(tempThumbnailPath)
            }
        }
        attachmentRepository.delete(attachment)
        log.auditEventAfterCommit(
            event = "attachment.deleted",
            actor = actor,
            target = attachmentAuditTarget(attachment, actor),
            details = mapOf(
                "originalFilename" to attachment.originalFilename,
                "storedFilename" to attachment.storedFilename,
                "size" to attachment.size,
                "reason" to "not_in_finalized_attachment_ids"
            )
        )
    }

    private fun attachmentAuditTarget(attachment: Attachment, actor: AuditActor?): Map<String, Any?> =
        mapOf(
            "type" to "Attachment",
            "id" to attachment.id,
            "contextType" to attachment.contextType,
            "contextId" to attachment.contextId,
            "uploadSessionId" to attachment.uploadSessionId,
            "ownerId" to attachment.createdBy,
            "ownerName" to ownerName(attachment.createdBy, actor),
            "filename" to attachment.originalFilename
        )

    private fun sessionAuditTarget(
        sessionId: UUID,
        contextType: AttachmentContextType,
        contextId: String?,
        ownerId: Long,
        actor: AuditActor?
    ): Map<String, Any?> = mapOf(
        "type" to "AttachmentUploadSession",
        "id" to sessionId,
        "contextType" to contextType,
        "contextId" to contextId,
        "ownerId" to ownerId,
        "ownerName" to ownerName(ownerId, actor)
    )

    private fun ownerName(ownerId: Long, actor: AuditActor?): String? =
        actor?.takeIf { it.id == ownerId }?.name
}
