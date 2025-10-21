package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.exception.AttachmentExtensionBlockedException
import com.tistory.shanepark.dutypark.attachment.exception.AttachmentTooLargeException
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import org.springframework.stereotype.Service
import org.springframework.web.multipart.MultipartFile

@Service
class AttachmentValidationService(
    private val storageProperties: StorageProperties
) {

    fun validateFile(file: MultipartFile) {
        validateFileSize(file)
        validateFileExtension(file)
    }

    fun validateFileSize(file: MultipartFile) {
        val maxSizeBytes = storageProperties.maxFileSize.toBytes()
        if (file.size > maxSizeBytes) {
            throw AttachmentTooLargeException(
                filename = file.originalFilename ?: "unknown",
                size = file.size,
                maxSize = maxSizeBytes
            )
        }
    }

    fun validateFileExtension(file: MultipartFile) {
        val filename = file.originalFilename ?: throw IllegalArgumentException("Filename cannot be null")
        val extension = getFileExtension(filename)

        if (extension != null && isBlacklisted(extension)) {
            throw AttachmentExtensionBlockedException(
                filename = filename,
                extension = extension
            )
        }
    }

    private fun getFileExtension(filename: String): String? {
        val lastDotIndex = filename.lastIndexOf('.')
        if (lastDotIndex == -1 || lastDotIndex == filename.length - 1) {
            return null
        }
        return filename.substring(lastDotIndex + 1)
    }

    private fun isBlacklisted(extension: String): Boolean {
        return storageProperties.blacklistExt.any { it.equals(extension, ignoreCase = true) }
    }
}
