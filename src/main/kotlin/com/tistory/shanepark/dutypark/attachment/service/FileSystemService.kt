package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.common.config.logger
import org.springframework.stereotype.Service
import org.springframework.web.multipart.MultipartFile
import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path
import java.nio.file.StandardCopyOption

@Service
class FileSystemService {
    private val log = logger()

    fun writeFile(file: MultipartFile, targetPath: Path): Path {
        try {
            ensureDirectoryExists(targetPath.parent)

            Files.copy(file.inputStream, targetPath, StandardCopyOption.REPLACE_EXISTING)

            log.info("File written successfully: {}", targetPath)
            return targetPath
        } catch (e: IOException) {
            log.error("Failed to write file to {}: {}", targetPath, e.message)
            cleanupFile(targetPath)
            throw IOException("Failed to write file: ${targetPath.fileName}", e)
        }
    }

    fun moveFile(sourcePath: Path, targetPath: Path): Path {
        try {
            ensureDirectoryExists(targetPath.parent)

            Files.move(sourcePath, targetPath, StandardCopyOption.ATOMIC_MOVE, StandardCopyOption.REPLACE_EXISTING)

            log.info("File moved successfully: {} -> {}", sourcePath, targetPath)
            return targetPath
        } catch (e: IOException) {
            log.error("Failed to move file from {} to {}: {}", sourcePath, targetPath, e.message)

            try {
                Files.copy(sourcePath, targetPath, StandardCopyOption.REPLACE_EXISTING)
                Files.delete(sourcePath)
                log.warn("File moved using copy+delete fallback: {} -> {}", sourcePath, targetPath)
                return targetPath
            } catch (fallbackException: IOException) {
                log.error("Fallback copy+delete also failed: {}", fallbackException.message)
                cleanupFile(targetPath)
                throw IOException("Failed to move file from ${sourcePath.fileName} to ${targetPath.fileName}", e)
            }
        }
    }

    fun deleteFile(path: Path) {
        try {
            if (Files.exists(path)) {
                Files.delete(path)
                log.info("File deleted successfully: {}", path)
            }
        } catch (e: IOException) {
            log.error("Failed to delete file {}: {}", path, e.message)
            throw IOException("Failed to delete file: ${path.fileName}", e)
        }
    }

    fun deleteDirectory(path: Path) {
        try {
            if (Files.exists(path) && Files.isDirectory(path)) {
                Files.walk(path)
                    .sorted(Comparator.reverseOrder())
                    .forEach { Files.deleteIfExists(it) }
                log.info("Directory deleted successfully: {}", path)
            }
        } catch (e: IOException) {
            log.error("Failed to delete directory {}: {}", path, e.message)
            throw IOException("Failed to delete directory: ${path.fileName}", e)
        }
    }

    fun fileExists(path: Path): Boolean {
        return Files.exists(path)
    }

    private fun ensureDirectoryExists(directory: Path) {
        if (!Files.exists(directory)) {
            Files.createDirectories(directory)
            log.debug("Created directory: {}", directory)
        }
    }

    private fun cleanupFile(path: Path) {
        try {
            if (Files.exists(path)) {
                Files.delete(path)
                log.info("Cleaned up orphaned file: {}", path)
            }
        } catch (e: IOException) {
            log.warn("Failed to cleanup orphaned file {}: {}", path, e.message)
        }
    }
}
