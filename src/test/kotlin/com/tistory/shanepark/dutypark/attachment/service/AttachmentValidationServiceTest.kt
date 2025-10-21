package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.exception.AttachmentExtensionBlockedException
import com.tistory.shanepark.dutypark.attachment.exception.AttachmentTooLargeException
import com.tistory.shanepark.dutypark.common.config.StorageProperties
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.mock.web.MockMultipartFile
import org.springframework.util.unit.DataSize

class AttachmentValidationServiceTest {

    private lateinit var validationService: AttachmentValidationService
    private lateinit var storageProperties: StorageProperties

    @BeforeEach
    fun setUp() {
        storageProperties = StorageProperties(
            root = "storage",
            maxFileSize = DataSize.ofMegabytes(50),
            blacklistExt = listOf("exe", "bat", "cmd", "sh", "js"),
            thumbnail = StorageProperties.ThumbnailProperties(maxSide = 200),
            sessionExpirationHours = 24
        )
        validationService = AttachmentValidationService(storageProperties)
    }

    @Test
    fun `should accept valid image file`() {
        val file = MockMultipartFile(
            "file",
            "test.png",
            "image/png",
            ByteArray(1024)
        )

        validationService.validateFile(file)
    }

    @Test
    fun `should accept valid pdf file`() {
        val file = MockMultipartFile(
            "file",
            "document.pdf",
            "application/pdf",
            ByteArray(1024)
        )

        validationService.validateFile(file)
    }

    @Test
    fun `should accept file at maximum size limit`() {
        val maxSizeBytes = storageProperties.maxFileSize.toBytes()
        val file = MockMultipartFile(
            "file",
            "large.pdf",
            "application/pdf",
            ByteArray(maxSizeBytes.toInt())
        )

        validationService.validateFile(file)
    }

    @Test
    fun `should accept file with uppercase extension not in blacklist`() {
        val file = MockMultipartFile(
            "file",
            "test.PNG",
            "image/png",
            ByteArray(1024)
        )

        validationService.validateFile(file)
    }

    @Test
    fun `should accept file without extension`() {
        val file = MockMultipartFile(
            "file",
            "noextension",
            "application/octet-stream",
            ByteArray(1024)
        )

        validationService.validateFile(file)
    }

    @Test
    fun `should reject file exceeding size limit`() {
        val maxSizeBytes = storageProperties.maxFileSize.toBytes()
        val file = MockMultipartFile(
            "file",
            "toolarge.pdf",
            "application/pdf",
            ByteArray((maxSizeBytes + 1).toInt())
        )

        try {
            validationService.validateFile(file)
            throw AssertionError("Expected AttachmentTooLargeException")
        } catch (e: AttachmentTooLargeException) {
            assertThat(e.filename).isEqualTo("toolarge.pdf")
            assertThat(e.size).isEqualTo(maxSizeBytes + 1)
            assertThat(e.maxSize).isEqualTo(maxSizeBytes)
            assertThat(e.errorCode).isEqualTo(413)
        }
    }

    @Test
    fun `should reject exe file`() {
        val file = MockMultipartFile(
            "file",
            "malicious.exe",
            "application/octet-stream",
            ByteArray(1024)
        )

        try {
            validationService.validateFile(file)
            throw AssertionError("Expected AttachmentExtensionBlockedException")
        } catch (e: AttachmentExtensionBlockedException) {
            assertThat(e.filename).isEqualTo("malicious.exe")
            assertThat(e.extension).isEqualTo("exe")
            assertThat(e.errorCode).isEqualTo(400)
        }
    }

    @Test
    fun `should reject bat file`() {
        val file = MockMultipartFile(
            "file",
            "script.bat",
            "application/octet-stream",
            ByteArray(1024)
        )

        assertThatThrownBy { validationService.validateFile(file) }
            .isInstanceOf(AttachmentExtensionBlockedException::class.java)
            .hasMessageContaining("bat")
    }

    @Test
    fun `should reject sh file`() {
        val file = MockMultipartFile(
            "file",
            "script.sh",
            "application/x-sh",
            ByteArray(1024)
        )

        assertThatThrownBy { validationService.validateFile(file) }
            .isInstanceOf(AttachmentExtensionBlockedException::class.java)
            .hasMessageContaining("sh")
    }

    @Test
    fun `should reject js file`() {
        val file = MockMultipartFile(
            "file",
            "code.js",
            "application/javascript",
            ByteArray(1024)
        )

        assertThatThrownBy { validationService.validateFile(file) }
            .isInstanceOf(AttachmentExtensionBlockedException::class.java)
            .hasMessageContaining("js")
    }

    @Test
    fun `should reject blacklisted extension case-insensitively`() {
        val fileUppercase = MockMultipartFile(
            "file",
            "malicious.EXE",
            "application/octet-stream",
            ByteArray(1024)
        )

        assertThatThrownBy { validationService.validateFile(fileUppercase) }
            .isInstanceOf(AttachmentExtensionBlockedException::class.java)
            .hasMessageContaining("EXE")

        val fileMixedCase = MockMultipartFile(
            "file",
            "malicious.ExE",
            "application/octet-stream",
            ByteArray(1024)
        )

        assertThatThrownBy { validationService.validateFile(fileMixedCase) }
            .isInstanceOf(AttachmentExtensionBlockedException::class.java)
            .hasMessageContaining("ExE")
    }
}
