package com.tistory.shanepark.dutypark.attachment.service

import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.io.TempDir
import org.springframework.mock.web.MockMultipartFile
import java.io.IOException
import java.nio.file.Files
import java.nio.file.Path

class FileSystemServiceTest {

    private lateinit var fileSystemService: FileSystemService

    @TempDir
    lateinit var tempDir: Path

    @BeforeEach
    fun setUp() {
        fileSystemService = FileSystemService()
    }

    @AfterEach
    fun cleanup() {
        if (Files.exists(tempDir)) {
            Files.walk(tempDir)
                .sorted(Comparator.reverseOrder())
                .forEach { Files.deleteIfExists(it) }
        }
    }

    @Test
    fun `should write file successfully`() {
        val content = "test content".toByteArray()
        val file = MockMultipartFile("file", "test.txt", "text/plain", content)
        val targetPath = tempDir.resolve("test.txt")

        val result = fileSystemService.writeFile(file, targetPath)

        assertThat(Files.exists(result)).isTrue()
        assertThat(Files.readAllBytes(result)).isEqualTo(content)
    }

    @Test
    fun `should create directory when writing file`() {
        val content = "test content".toByteArray()
        val file = MockMultipartFile("file", "test.txt", "text/plain", content)
        val targetPath = tempDir.resolve("subdir").resolve("test.txt")

        val result = fileSystemService.writeFile(file, targetPath)

        assertThat(Files.exists(result.parent)).isTrue()
        assertThat(Files.exists(result)).isTrue()
    }

    @Test
    fun `should move file successfully`() {
        val content = "test content".toByteArray()
        val sourcePath = tempDir.resolve("source.txt")
        Files.write(sourcePath, content)

        val targetPath = tempDir.resolve("target.txt")

        val result = fileSystemService.moveFile(sourcePath, targetPath)

        assertThat(Files.exists(result)).isTrue()
        assertThat(Files.exists(sourcePath)).isFalse()
        assertThat(Files.readAllBytes(result)).isEqualTo(content)
    }

    @Test
    fun `should move file to different directory`() {
        val content = "test content".toByteArray()
        val sourcePath = tempDir.resolve("source.txt")
        Files.write(sourcePath, content)

        val targetPath = tempDir.resolve("subdir").resolve("target.txt")

        val result = fileSystemService.moveFile(sourcePath, targetPath)

        assertThat(Files.exists(result)).isTrue()
        assertThat(Files.exists(sourcePath)).isFalse()
        assertThat(Files.readAllBytes(result)).isEqualTo(content)
    }

    @Test
    fun `should delete file successfully`() {
        val content = "test content".toByteArray()
        val filePath = tempDir.resolve("test.txt")
        Files.write(filePath, content)

        fileSystemService.deleteFile(filePath)

        assertThat(Files.exists(filePath)).isFalse()
    }

    @Test
    fun `should not throw exception when deleting non-existent file`() {
        val filePath = tempDir.resolve("non-existent.txt")

        fileSystemService.deleteFile(filePath)

        assertThat(Files.exists(filePath)).isFalse()
    }

    @Test
    fun `should delete directory with contents`() {
        val dirPath = tempDir.resolve("testdir")
        Files.createDirectories(dirPath)
        Files.write(dirPath.resolve("file1.txt"), "content1".toByteArray())
        Files.write(dirPath.resolve("file2.txt"), "content2".toByteArray())

        val subDir = dirPath.resolve("subdir")
        Files.createDirectories(subDir)
        Files.write(subDir.resolve("file3.txt"), "content3".toByteArray())

        fileSystemService.deleteDirectory(dirPath)

        assertThat(Files.exists(dirPath)).isFalse()
    }

    @Test
    fun `should return true when file exists`() {
        val filePath = tempDir.resolve("test.txt")
        Files.write(filePath, "content".toByteArray())

        val exists = fileSystemService.fileExists(filePath)

        assertThat(exists).isTrue()
    }

    @Test
    fun `should return false when file does not exist`() {
        val filePath = tempDir.resolve("non-existent.txt")

        val exists = fileSystemService.fileExists(filePath)

        assertThat(exists).isFalse()
    }

    @Test
    fun `should cleanup orphaned file on write failure`() {
        val file = MockMultipartFile("file", "test.txt", "text/plain", "content".toByteArray())
        val invalidPath = tempDir.resolve("invalid").resolve("deep").resolve("nested").resolve("test.txt")

        Files.createDirectories(invalidPath.parent)
        Files.write(invalidPath, "existing".toByteArray())
        Files.setPosixFilePermissions(invalidPath.parent, emptySet())

        try {
            assertThatThrownBy {
                fileSystemService.writeFile(file, invalidPath)
            }.isInstanceOf(IOException::class.java)
        } finally {
            Files.setPosixFilePermissions(invalidPath.parent, setOf(
                java.nio.file.attribute.PosixFilePermission.OWNER_READ,
                java.nio.file.attribute.PosixFilePermission.OWNER_WRITE,
                java.nio.file.attribute.PosixFilePermission.OWNER_EXECUTE
            ))
        }
    }

    @Test
    fun `should replace existing file when writing`() {
        val filePath = tempDir.resolve("test.txt")
        Files.write(filePath, "old content".toByteArray())

        val newContent = "new content".toByteArray()
        val file = MockMultipartFile("file", "test.txt", "text/plain", newContent)

        fileSystemService.writeFile(file, filePath)

        assertThat(Files.readAllBytes(filePath)).isEqualTo(newContent)
    }
}
