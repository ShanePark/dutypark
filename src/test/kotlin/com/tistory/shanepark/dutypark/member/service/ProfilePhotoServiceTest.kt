package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.mock.web.MockMultipartFile
import java.nio.file.Files
import java.nio.file.Path
import javax.imageio.ImageIO
import java.awt.image.BufferedImage
import java.io.ByteArrayOutputStream

class ProfilePhotoServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var profilePhotoService: ProfilePhotoService

    @Autowired
    lateinit var storagePathResolver: StoragePathResolver

    private val createdDirectories = mutableListOf<Path>()

    @AfterEach
    fun cleanup() {
        createdDirectories.forEach { dir ->
            if (Files.exists(dir)) {
                Files.walk(dir)
                    .sorted(Comparator.reverseOrder())
                    .forEach { Files.deleteIfExists(it) }
            }
        }
        createdDirectories.clear()
    }

    @Test
    fun `getProfilePhotoPath returns original path when thumbnail is false`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = "PROFILE/${member.id}/test-photo.png"
        memberRepository.save(member)

        // When
        val result = profilePhotoService.getProfilePhotoPath(member.id!!, thumbnail = false)

        // Then
        assertThat(result).isNotNull
        assertThat(result.toString()).contains("PROFILE/${member.id}/test-photo.png")
        assertThat(result.toString()).doesNotContain("_thumb")
    }

    @Test
    fun `getProfilePhotoPath returns thumbnail path when thumbnail is true`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = "PROFILE/${member.id}/test-photo.png"
        memberRepository.save(member)

        // When
        val result = profilePhotoService.getProfilePhotoPath(member.id!!, thumbnail = true)

        // Then
        assertThat(result).isNotNull
        assertThat(result.toString()).contains("PROFILE/${member.id}/test-photo_thumb.png")
    }

    @Test
    fun `getProfilePhotoPath returns null when no profile photo exists`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        memberRepository.save(member)

        // When
        val result = profilePhotoService.getProfilePhotoPath(member.id!!)

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `getProfilePhotoPath returns null when member does not exist`() {
        // When
        val result = profilePhotoService.getProfilePhotoPath(999999L)

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `setProfilePhoto saves photo and generates thumbnail`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        memberRepository.save(member)
        em.flush()
        em.clear()

        val imageBytes = createTestPngImage()
        val file = MockMultipartFile(
            "file",
            "test-profile.png",
            "image/png",
            imageBytes
        )
        val loginMember = loginMember(member)

        // Track the directory for cleanup
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)

        // When
        profilePhotoService.setProfilePhoto(loginMember, file)
        em.flush()
        em.clear()

        // Then
        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoPath).isNotNull
        assertThat(updatedMember.profilePhotoPath).startsWith("PROFILE/${member.id}/")
        assertThat(updatedMember.profilePhotoPath).endsWith(".png")

        // Verify files exist
        val originalPath = storagePathResolver.getStorageRoot().resolve(updatedMember.profilePhotoPath!!)
        assertThat(Files.exists(originalPath)).isTrue()

        val thumbnailPath = profilePhotoService.getProfilePhotoPath(member.id!!, thumbnail = true)
        assertThat(thumbnailPath).isNotNull
        assertThat(Files.exists(thumbnailPath!!)).isTrue()
    }

    @Test
    fun `setProfilePhoto increments profilePhotoVersion`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        member.profilePhotoVersion = 0
        memberRepository.save(member)
        em.flush()
        em.clear()

        val loginMember = loginMember(member)
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)

        // When
        val imageBytes = createTestPngImage()
        val file = MockMultipartFile("file", "test.png", "image/png", imageBytes)
        profilePhotoService.setProfilePhoto(loginMember, file)
        em.flush()
        em.clear()

        // Then
        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoVersion).isEqualTo(1)
    }

    @Test
    fun `setProfilePhoto increments version on each upload`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        member.profilePhotoVersion = 5
        memberRepository.save(member)
        em.flush()
        em.clear()

        val loginMember = loginMember(member)
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)

        // When - First upload
        val firstImage = createTestPngImage()
        val firstFile = MockMultipartFile("file", "first.png", "image/png", firstImage)
        profilePhotoService.setProfilePhoto(loginMember, firstFile)
        em.flush()
        em.clear()

        // Then
        var updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoVersion).isEqualTo(6)

        // When - Second upload
        val secondImage = createTestPngImage()
        val secondFile = MockMultipartFile("file", "second.png", "image/png", secondImage)
        profilePhotoService.setProfilePhoto(loginMember, secondFile)
        em.flush()
        em.clear()

        // Then
        updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoVersion).isEqualTo(7)
    }

    @Test
    fun `setProfilePhoto replaces existing photo`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        memberRepository.save(member)
        em.flush()
        em.clear()

        val loginMember = loginMember(member)
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)

        // Upload first photo
        val firstImage = createTestPngImage()
        val firstFile = MockMultipartFile("file", "first.png", "image/png", firstImage)
        profilePhotoService.setProfilePhoto(loginMember, firstFile)
        em.flush()
        em.clear()

        val firstMember = memberRepository.findById(member.id!!).orElseThrow()
        val firstPhotoPath = firstMember.profilePhotoPath!!
        val firstOriginalPath = storagePathResolver.getStorageRoot().resolve(firstPhotoPath)

        // When - Upload second photo
        val secondImage = createTestPngImage()
        val secondFile = MockMultipartFile("file", "second.png", "image/png", secondImage)
        profilePhotoService.setProfilePhoto(loginMember, secondFile)
        em.flush()
        em.clear()

        // Then
        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoPath).isNotNull
        assertThat(updatedMember.profilePhotoPath).isNotEqualTo(firstPhotoPath)

        // Old files should be deleted
        assertThat(Files.exists(firstOriginalPath)).isFalse()

        // New files should exist
        val newOriginalPath = storagePathResolver.getStorageRoot().resolve(updatedMember.profilePhotoPath!!)
        assertThat(Files.exists(newOriginalPath)).isTrue()
    }

    @Test
    fun `deleteProfilePhoto removes photo and files`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        memberRepository.save(member)
        em.flush()
        em.clear()

        val loginMember = loginMember(member)
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)

        // Upload photo first
        val imageBytes = createTestPngImage()
        val file = MockMultipartFile("file", "test.png", "image/png", imageBytes)
        profilePhotoService.setProfilePhoto(loginMember, file)
        em.flush()
        em.clear()

        val memberWithPhoto = memberRepository.findById(member.id!!).orElseThrow()
        val photoPath = memberWithPhoto.profilePhotoPath!!
        val originalPath = storagePathResolver.getStorageRoot().resolve(photoPath)
        assertThat(Files.exists(originalPath)).isTrue()

        // When
        profilePhotoService.deleteProfilePhoto(loginMember)
        em.flush()
        em.clear()

        // Then
        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoPath).isNull()
        assertThat(Files.exists(originalPath)).isFalse()
    }

    @Test
    fun `deleteProfilePhoto increments profilePhotoVersion`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        member.profilePhotoVersion = 0
        memberRepository.save(member)
        em.flush()
        em.clear()

        val loginMember = loginMember(member)
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)

        // Upload photo first (version becomes 1)
        val imageBytes = createTestPngImage()
        val file = MockMultipartFile("file", "test.png", "image/png", imageBytes)
        profilePhotoService.setProfilePhoto(loginMember, file)
        em.flush()
        em.clear()

        val memberWithPhoto = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(memberWithPhoto.profilePhotoVersion).isEqualTo(1)

        // When - delete photo (version becomes 2)
        profilePhotoService.deleteProfilePhoto(loginMember)
        em.flush()
        em.clear()

        // Then
        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.profilePhotoPath).isNull()
        assertThat(updatedMember.profilePhotoVersion).isEqualTo(2)
    }

    @Test
    fun `setProfilePhoto rejects non-image files`() {
        // Given
        val member = TestData.member
        memberRepository.save(member)
        val loginMember = loginMember(member)

        val file = MockMultipartFile(
            "file",
            "document.pdf",
            "application/pdf",
            "fake pdf content".toByteArray()
        )

        // When & Then
        assertThatThrownBy {
            profilePhotoService.setProfilePhoto(loginMember, file)
        }.isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("image")
    }

    private fun createTestPngImage(): ByteArray {
        val image = BufferedImage(100, 100, BufferedImage.TYPE_INT_ARGB)
        val graphics = image.createGraphics()
        graphics.fillRect(0, 0, 100, 100)
        graphics.dispose()

        val outputStream = ByteArrayOutputStream()
        ImageIO.write(image, "png", outputStream)
        return outputStream.toByteArray()
    }
}
