package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import org.springframework.stereotype.Service
import java.nio.file.Path
import java.nio.file.Paths
import java.util.UUID

@Service
class StoragePathResolver(
    private val storageProperties: StorageProperties
) {

    fun resolveTemporaryDirectory(sessionId: UUID): Path {
        return Paths.get(storageProperties.root, "_tmp", sessionId.toString())
    }

    fun resolvePermanentDirectory(contextType: AttachmentContextType, contextId: String): Path {
        return Paths.get(storageProperties.root, contextType.name, contextId)
    }

    fun resolveTemporaryFilePath(sessionId: UUID, storedFilename: String): Path {
        return resolveTemporaryDirectory(sessionId).resolve(storedFilename)
    }

    fun resolvePermanentFilePath(
        contextType: AttachmentContextType,
        contextId: String,
        storedFilename: String
    ): Path {
        return resolvePermanentDirectory(contextType, contextId).resolve(storedFilename)
    }

    fun resolveThumbnailPath(filePath: Path, storedFilename: String): Path {
        val thumbnailFilename = generateThumbnailFilename(storedFilename)
        return filePath.parent.resolve(thumbnailFilename)
    }

    private fun generateThumbnailFilename(storedFilename: String): String {
        val dotIndex = storedFilename.lastIndexOf('.')
        val baseFilename = if (dotIndex > 0) {
            storedFilename.substring(0, dotIndex)
        } else {
            storedFilename
        }
        return "thumb-$baseFilename.png"
    }

    fun getStorageRoot(): Path {
        return Paths.get(storageProperties.root)
    }
}
