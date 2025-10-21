package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.common.config.logger
import net.coobird.thumbnailator.Thumbnails
import org.springframework.stereotype.Component
import java.nio.file.Path
import javax.imageio.ImageIO

@Component
class ImageThumbnailGenerator : ThumbnailGenerator {
    private val log = logger()

    override fun canGenerate(contentType: String): Boolean {
        if (!contentType.startsWith("image/", ignoreCase = true)) {
            return false
        }

        val format = contentType.substring(6).lowercase()
        val normalizedFormat = when (format) {
            "jpg" -> "jpeg"
            else -> format
        }

        return ImageIO.getReaderFormatNames().any { it.equals(normalizedFormat, ignoreCase = true) }
    }

    override fun generate(sourcePath: Path, targetPath: Path, maxSide: Int) {
        try {
            Thumbnails.of(sourcePath.toFile())
                .size(maxSide, maxSide)
                .outputFormat("png")
                .toFile(targetPath.toFile())
            log.info("Thumbnail generated successfully: {} -> {}", sourcePath.fileName, targetPath.fileName)
        } catch (e: Exception) {
            log.error("Failed to generate thumbnail for {}: {}", sourcePath.fileName, e.message)
            throw e
        }
    }
}
