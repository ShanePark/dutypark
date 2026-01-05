package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.service.AttachmentValidationService
import com.tistory.shanepark.dutypark.attachment.service.ImageThumbnailGenerator
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.config.logger
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
        val photoPath = member.profilePhotoPath ?: return null

        val targetPath = if (thumbnail) toThumbnailPath(photoPath) else photoPath
        return storagePathResolver.getStorageRoot().resolve(targetPath)
    }

    fun setProfilePhoto(loginMember: LoginMember, file: MultipartFile) {
        validationService.validateFile(file)
        validateImageFile(file)

        val member = memberRepository.findById(loginMember.id).orElseThrow()

        deleteExistingPhotos(member.profilePhotoPath)

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

        log.info("Profile photo set: memberId={}, path={}, version={}", loginMember.id, relativePath, member.profilePhotoVersion)
    }

    fun deleteProfilePhoto(loginMember: LoginMember) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()

        deleteExistingPhotos(member.profilePhotoPath)
        member.profilePhotoPath = null
        member.incrementProfilePhotoVersion()

        log.info("Profile photo deleted: memberId={}, version={}", loginMember.id, member.profilePhotoVersion)
    }

    private fun deleteExistingPhotos(photoPath: String?) {
        if (photoPath == null) return

        deleteFile(photoPath)
        deleteFile(toThumbnailPath(photoPath))
    }

    private fun deleteFile(relativePath: String) {
        try {
            val fullPath = storagePathResolver.getStorageRoot().resolve(relativePath)
            if (Files.exists(fullPath)) {
                Files.delete(fullPath)
                log.debug("Deleted file: {}", fullPath)
            }
        } catch (e: Exception) {
            log.warn("Failed to delete file: {}", relativePath, e)
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

    private fun validateImageFile(file: MultipartFile) {
        val contentType = file.contentType ?: throw IllegalArgumentException("Content type is required")
        if (!contentType.startsWith("image/")) {
            throw IllegalArgumentException("Only image files are allowed")
        }
    }
}
