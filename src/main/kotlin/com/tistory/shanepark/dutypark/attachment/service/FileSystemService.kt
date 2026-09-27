package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditContext
import org.springframework.stereotype.Service
import org.springframework.web.multipart.MultipartFile
import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption
import java.util.Collections
import java.util.IdentityHashMap

private const val MAX_ATTACHMENT_LOG_CAUSE_DEPTH = 8
private const val MAX_ATTACHMENT_LOG_STACK_FRAMES = 32

internal fun Throwable.toAttachmentLogDiagnostics(): Map<String, Any?> {
    val seen = Collections.newSetFromMap(IdentityHashMap<Throwable, Boolean>())
    val causes = mutableListOf<Throwable>()
    var current: Throwable? = this
    while (current != null && seen.add(current) && causes.size < MAX_ATTACHMENT_LOG_CAUSE_DEPTH) {
        causes += current
        current = current.cause
    }

    val stackFrames = mutableListOf<String>()
    var omittedStackFrameCount = 0
    causes.forEachIndexed { depth, cause ->
        val frames = cause.stackTrace
        val remainingCapacity = MAX_ATTACHMENT_LOG_STACK_FRAMES - stackFrames.size
        stackFrames += frames.take(remainingCapacity).map { "cause[$depth] at $it" }
        omittedStackFrameCount += (frames.size - remainingCapacity).coerceAtLeast(0)
    }

    return linkedMapOf(
        "exceptionType" to javaClass.name,
        "causeTypes" to causes.drop(1).map { it.javaClass.name },
        "stackFrames" to stackFrames,
        "omittedStackFrameCount" to omittedStackFrameCount
    )
}

@Service
class FileSystemService {
    private val log = logger()

    fun writeFile(file: MultipartFile, targetPath: Path): Path {
        try {
            ensureDirectoryExists(targetPath.parent)
            Files.copy(file.inputStream, targetPath, StandardCopyOption.REPLACE_EXISTING)
            return targetPath
        } catch (e: IOException) {
            log.error(
                "Attachment file write failed: {}",
                auditContext(
                    mapOf(
                        "operation" to "write_file",
                        "path" to targetPath.toString(),
                        "originalFilename" to file.originalFilename,
                        "contentType" to file.contentType,
                        "size" to file.size
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
            cleanupFile(targetPath)
            throw IOException("Failed to write file: ${targetPath.fileName}", e)
        }
    }

    fun deleteFile(path: Path) {
        try {
            if (Files.exists(path)) {
                Files.delete(path)
            }
        } catch (e: IOException) {
            log.error(
                "Attachment file deletion failed: {}",
                auditContext(
                    mapOf(
                        "operation" to "delete_file",
                        "path" to path.toString()
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
            throw IOException("Failed to delete file: ${path.fileName}", e)
        }
    }

    fun deleteDirectory(path: Path) {
        try {
            if (Files.exists(path) && Files.isDirectory(path)) {
                Files.walk(path)
                    .sorted(Comparator.reverseOrder())
                    .forEach { Files.deleteIfExists(it) }
            }
        } catch (e: IOException) {
            log.error(
                "Attachment directory deletion failed: {}",
                auditContext(
                    mapOf(
                        "operation" to "delete_directory",
                        "path" to path.toString()
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
            throw IOException("Failed to delete directory: ${path.fileName}", e)
        }
    }

    fun fileExists(path: Path): Boolean {
        return Files.exists(path)
    }

    private fun ensureDirectoryExists(directory: Path) {
        if (!Files.exists(directory)) {
            Files.createDirectories(directory)
        }
    }

    private fun cleanupFile(path: Path) {
        try {
            if (Files.exists(path)) {
                Files.delete(path)
            }
        } catch (e: IOException) {
            log.warn(
                "Orphaned attachment file cleanup failed: {}",
                auditContext(
                    mapOf(
                        "operation" to "cleanup_orphaned_file",
                        "path" to path.toString()
                    ) + e.toAttachmentLogDiagnostics()
                )
            )
        }
    }
}
