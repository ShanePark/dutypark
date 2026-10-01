package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.attachment.service.AttachmentValidationService
import com.tistory.shanepark.dutypark.attachment.service.ImageThumbnailGenerator
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.attachment.service.toAttachmentLogDiagnostics
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import org.springframework.web.multipart.MultipartFile
import java.nio.file.Files
import java.nio.file.Path
import java.util.*

@Service
@Transactional
class ProfilePhotoService(
    private val memberRepository: MemberRepository,
    private val attachmentRepository: AttachmentRepository,
    private val attachmentService: AttachmentService,
    private val storagePathResolver: StoragePathResolver,
    private val validationService: AttachmentValidationService,
    private val thumbnailGenerator: ImageThumbnailGenerator,
) {
    private val log = logger()

    companion object {
        private const val THUMBNAIL_SUFFIX = "_thumb"
        private const val THUMBNAIL_SIZE = 200
    }

    @Transactional(readOnly = true)
    fun getProfilePhotoPath(memberId: Long, thumbnail: Boolean = false): Path? {
        val member = memberRepository.findById(memberId).orElse(null) ?: return null
        val photoPath = member.profilePhotoPath
            ?: return legacyProfilePhotoPath(memberId, thumbnail)

        val targetPath = if (thumbnail) toThumbnailPath(photoPath) else photoPath
        val resolvedPath = storagePathResolver.getStorageRoot().resolve(targetPath)
        if (!thumbnail || Files.exists(resolvedPath)) {
            return resolvedPath
        }

        return legacyProfilePhotoPath(memberId, thumbnail, photoPath) ?: resolvedPath
    }

    fun setProfilePhoto(loginMember: LoginMember, file: MultipartFile) {
        validationService.validateFile(file)
        validateImageFile(file)

        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val previousPhotoPath = member.profilePhotoPath
        val previousVersion = member.profilePhotoVersion

        deleteExistingPhotos(previousPhotoPath, loginMember)
        deleteLegacyProfilePhotos(member.id!!, loginMember)

        val directory = storagePathResolver.resolvePermanentDirectory(
            AttachmentContextType.PROFILE,
            loginMember.id.toString()
        )
        Files.createDirectories(directory)

        val baseFilename = UUID.randomUUID().toString()
        val originalFilename = "$baseFilename.png"
        val thumbnailFilename = "$baseFilename${THUMBNAIL_SUFFIX}.png"

        val originalPath = directory.resolve(originalFilename)
        val thumbnailPath = directory.resolve(thumbnailFilename)

        file.transferTo(originalPath)
        thumbnailGenerator.generate(originalPath, thumbnailPath, THUMBNAIL_SIZE)

        val relativePath = "PROFILE/${loginMember.id}/$originalFilename"
        member.profilePhotoPath = relativePath
        member.incrementProfilePhotoVersion()

        log.auditChangeAfterCommit(
            event = "profile_photo_updated",
            actor = loginMember.toAuditActor(),
            target = mapOf("memberId" to member.id),
            before = mapOf("profilePhotoPath" to previousPhotoPath, "profilePhotoVersion" to previousVersion),
            after = mapOf("profilePhotoPath" to member.profilePhotoPath, "profilePhotoVersion" to member.profilePhotoVersion),
        )
    }

    fun deleteProfilePhoto(loginMember: LoginMember) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val previousPhotoPath = member.profilePhotoPath
        val previousVersion = member.profilePhotoVersion

        deleteExistingPhotos(previousPhotoPath, loginMember)
        deleteLegacyProfilePhotos(member.id!!, loginMember)
        member.profilePhotoPath = null
        member.incrementProfilePhotoVersion()

        log.auditChangeAfterCommit(
            event = "profile_photo_deleted",
            actor = loginMember.toAuditActor(),
            target = mapOf("memberId" to member.id),
            before = mapOf("profilePhotoPath" to previousPhotoPath, "profilePhotoVersion" to previousVersion),
            after = mapOf("profilePhotoPath" to member.profilePhotoPath, "profilePhotoVersion" to member.profilePhotoVersion),
        )
    }

    private fun deleteExistingPhotos(photoPath: String?, actor: LoginMember) {
        if (photoPath == null) return

        deleteFile(photoPath, actor)
        deleteFile(toThumbnailPath(photoPath), actor)
    }

    /**
     * Profile attachments predate Member.profilePhotoPath. They must be removed
     * together with the current path so an explicit replacement/deletion cannot
     * expose the old file through the legacy read fallback.
     */
    private fun deleteLegacyProfilePhotos(memberId: Long, actor: LoginMember) {
        val legacyAttachments = attachmentRepository.findAllByContextTypeAndContextId(
            AttachmentContextType.PROFILE,
            memberId.toString(),
        )

        legacyAttachments.forEach { attachment ->
            attachmentService.deleteAttachment(
                attachment,
                actor = actor.toAuditActor(),
                reason = "legacy_profile_photo",
            )
        }
    }

    private fun deleteFile(relativePath: String, actor: LoginMember) {
        try {
            val fullPath = storagePathResolver.getStorageRoot().resolve(relativePath)
            if (Files.exists(fullPath)) {
                Files.delete(fullPath)
            }
        } catch (e: Exception) {
            log.warn(
                "Profile photo file deletion failed {}",
                auditContext(
                    mapOf(
                        "actor" to actor.toAuditActor(),
                        "operation" to "delete_profile_photo_file",
                        "relativePath" to relativePath,
                    ) + e.toAttachmentLogDiagnostics()
                ),
            )
        }
    }

    private fun toThumbnailPath(originalPath: String): String {
        val lastDotIndex = originalPath.lastIndexOf('.')
        return if (lastDotIndex > 0) {
            "${originalPath.substring(0, lastDotIndex)}${THUMBNAIL_SUFFIX}${originalPath.substring(lastDotIndex)}"
        } else {
            "${originalPath}${THUMBNAIL_SUFFIX}"
        }
    }

    private fun legacyProfilePhotoPath(
        memberId: Long,
        thumbnail: Boolean,
        expectedPhotoPath: String? = null,
    ): Path? {
        val attachment = attachmentRepository
            .findAllByContextTypeAndContextIdOrderByOrderIndexAsc(
                AttachmentContextType.PROFILE,
                memberId.toString()
            )
            .firstOrNull()
            ?: return null

        val legacyPhotoPath = "PROFILE/$memberId/${attachment.storedFilename}"
        if (expectedPhotoPath != null && expectedPhotoPath != legacyPhotoPath) {
            return null
        }

        return if (thumbnail) {
            val thumbnailFilename = attachment.thumbnailFilename ?: return null
            storagePathResolver.resolveThumbnailPath(
                contextType = AttachmentContextType.PROFILE,
                contextId = memberId.toString(),
                uploadSessionId = null,
                thumbnailFilename = thumbnailFilename,
            )
        } else {
            storagePathResolver.resolveFilePath(
                contextType = AttachmentContextType.PROFILE,
                contextId = memberId.toString(),
                uploadSessionId = null,
                storedFilename = attachment.storedFilename,
            )
        }
    }

    private fun validateImageFile(file: MultipartFile) {
        val contentType = file.contentType ?: throw IllegalArgumentException("Content type is required")
        if (!contentType.startsWith("image/")) {
            throw IllegalArgumentException("Only image files are allowed")
        }
    }
}
