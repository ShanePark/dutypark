package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
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
            log.info(
                "Attachment thumbnail generated: {}",
                auditContext(
                    mapOf(
                        "sourcePath" to sourcePath.toString(),
                        "thumbnailPath" to targetPath.toString(),
                        "outputFormat" to "png",
                        "maxSide" to maxSide,
                        "outputSize" to targetPath.toFile().length()
                    )
                )
            )
        } catch (e: Exception) {
            log.error(
                "Attachment thumbnail generation failed: {}",
                auditContext(
                    mapOf(
                        "sourcePath" to sourcePath.toString(),
                        "thumbnailPath" to targetPath.toString(),
                        "maxSide" to maxSide,
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
            throw e
        }
    }
}
