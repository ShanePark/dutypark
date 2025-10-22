package com.tistory.shanepark.dutypark.attachment.controller

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.AttachmentDto
import com.tistory.shanepark.dutypark.attachment.dto.FinalizeSessionRequest
import com.tistory.shanepark.dutypark.attachment.dto.ReorderAttachmentsRequest
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.core.io.Resource
import org.springframework.core.io.UrlResource
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*
import org.springframework.web.multipart.MultipartFile
import java.util.*

@RestController
@RequestMapping("/api/attachments")
class AttachmentController(
    private val attachmentService: AttachmentService,
    private val pathResolver: StoragePathResolver
) {

    @PostMapping
    fun uploadFile(
        @Login loginMember: LoginMember,
        @RequestParam sessionId: UUID,
        @RequestParam file: MultipartFile
    ): AttachmentDto {
        val attachment = attachmentService.uploadFile(loginMember, sessionId, file)
        return AttachmentDto.from(attachment)
    }

    @PostMapping("/sessions/{sessionId}/finalize")
    fun finalizeSession(
        @Login loginMember: LoginMember,
        @PathVariable sessionId: UUID,
        @RequestBody request: FinalizeSessionRequest
    ) {
        attachmentService.finalizeSession(loginMember, sessionId, request)
    }

    @PostMapping("/reorder")
    fun reorderAttachments(
        @Login loginMember: LoginMember,
        @RequestBody request: ReorderAttachmentsRequest
    ) {
        attachmentService.reorderAttachments(loginMember, request)
    }

    @GetMapping("/{id}/download")
    fun downloadAttachment(
        @Login(required = false) loginMember: LoginMember?,
        @PathVariable id: UUID
    ): ResponseEntity<Resource> {
        val attachment = attachmentService.findById(loginMember, id)
            ?: return ResponseEntity.notFound().build()

        val filePath = pathResolver.resolveFilePath(
            attachment.contextType,
            attachment.contextId,
            attachment.uploadSessionId,
            attachment.storedFilename
        )

        val resource = UrlResource(filePath.toUri())
        if (!resource.exists()) {
            return ResponseEntity.notFound().build()
        }

        val sanitizedFilename = sanitizeFilename(attachment.originalFilename)

        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType(attachment.contentType))
            .header(HttpHeaders.CONTENT_DISPOSITION, "attachment; filename=\"$sanitizedFilename\"")
            .body(resource)
    }

    private fun sanitizeFilename(filename: String): String {
        return filename
            .replace("[\r\n]".toRegex(), "")
            .replace("\"", "\\\"")
            .take(255)
    }

    @GetMapping("/{id}/thumbnail")
    fun getThumbnail(
        @Login(required = false) loginMember: LoginMember?,
        @PathVariable id: UUID
    ): ResponseEntity<Resource> {
        val attachment = attachmentService.findById(loginMember, id)
            ?: return ResponseEntity.notFound().build()

        val thumbnailFilename = attachment.thumbnailFilename
            ?: return ResponseEntity.notFound().build()

        val thumbnailPath = pathResolver.resolveThumbnailPath(
            attachment.contextType,
            attachment.contextId,
            attachment.uploadSessionId,
            thumbnailFilename
        )

        val resource = UrlResource(thumbnailPath.toUri())
        if (!resource.exists()) {
            return ResponseEntity.notFound().build()
        }

        return ResponseEntity.ok()
            .contentType(MediaType.parseMediaType(attachment.thumbnailContentType ?: "image/png"))
            .body(resource)
    }

    @DeleteMapping("/{id}")
    fun deleteAttachment(
        @Login loginMember: LoginMember,
        @PathVariable id: UUID
    ) {
        attachmentService.deleteAttachment(loginMember, id)
    }

    @GetMapping
    fun listAttachments(
        @Login(required = false) loginMember: LoginMember?,
        @RequestParam contextType: AttachmentContextType,
        @RequestParam contextId: String
    ): List<AttachmentDto> {
        return attachmentService.listAttachments(loginMember, contextType, contextId)
    }
}
