package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.common.config.StorageProperties
import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.stereotype.Service
import java.nio.file.Path

@Service
class ThumbnailService(
    private val thumbnailGenerators: List<ThumbnailGenerator>,
    private val storageProperties: StorageProperties
) {
    private val log = logger()

    fun generateThumbnail(sourcePath: Path, targetPath: Path, contentType: String): Boolean {
        val generator = thumbnailGenerators.firstOrNull { it.canGenerate(contentType) }

        if (generator == null) {
            log.debug("No thumbnail generator found for content type: {}", contentType)
            return false
        }

        return try {
            generator.generate(sourcePath, targetPath, storageProperties.thumbnail.maxSide)
            log.info("Thumbnail generated successfully for {}", sourcePath.fileName)
            true
        } catch (e: Exception) {
            log.error("Thumbnail generation failed for {} with content type {}: {}",
                sourcePath.fileName, contentType, e.message)
            false
        }
    }

    fun canGenerateThumbnail(contentType: String): Boolean {
        return thumbnailGenerators.any { it.canGenerate(contentType) }
    }
}
