package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.util.*

class ProfilePhotoServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var profilePhotoService: ProfilePhotoService

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Test
    fun `getProfilePhoto returns attachment when profile photo exists`() {
        // Given
        val member = TestData.member
        val attachment = createProfileAttachment(member.id!!)

        // When
        val result = profilePhotoService.getProfilePhoto(member.id!!)

        // Then
        assertThat(result).isNotNull
        assertThat(result!!.id).isEqualTo(attachment.id)
    }

    @Test
    fun `getProfilePhoto returns null when no profile photo exists`() {
        // Given
        val member = TestData.member

        // When
        val result = profilePhotoService.getProfilePhoto(member.id!!)

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `getProfilePhotoUrl returns thumbnail url when profile photo exists`() {
        // Given
        val member = TestData.member
        val attachment = createProfileAttachment(member.id!!)

        // When
        val result = profilePhotoService.getProfilePhotoUrl(member.id!!)

        // Then
        assertThat(result).isNotNull
        assertThat(result).isEqualTo("/api/attachments/${attachment.id}/thumbnail")
    }

    @Test
    fun `getProfilePhotoUrl returns null when no profile photo exists`() {
        // Given
        val member = TestData.member

        // When
        val result = profilePhotoService.getProfilePhotoUrl(member.id!!)

        // Then
        assertThat(result).isNull()
    }

    @Test
    fun `getProfilePhotoUrls returns map with urls for existing profile photos`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        val attachment1 = createProfileAttachment(member1.id!!)
        val attachment2 = createProfileAttachment(member2.id!!)

        // When
        val result = profilePhotoService.getProfilePhotoUrls(listOf(member1.id!!, member2.id!!))

        // Then
        assertThat(result).hasSize(2)
        assertThat(result[member1.id]).isEqualTo("/api/attachments/${attachment1.id}/thumbnail")
        assertThat(result[member2.id]).isEqualTo("/api/attachments/${attachment2.id}/thumbnail")
    }

    @Test
    fun `getProfilePhotoUrls returns null values for members without profile photos`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2
        val attachment1 = createProfileAttachment(member1.id!!)

        // When
        val result = profilePhotoService.getProfilePhotoUrls(listOf(member1.id!!, member2.id!!))

        // Then
        assertThat(result).hasSize(2)
        assertThat(result[member1.id]).isEqualTo("/api/attachments/${attachment1.id}/thumbnail")
        assertThat(result[member2.id]).isNull()
    }

    @Test
    fun `getProfilePhotoUrls returns empty map for empty member list`() {
        // Given
        val memberIds = emptyList<Long>()

        // When
        val result = profilePhotoService.getProfilePhotoUrls(memberIds)

        // Then
        assertThat(result).isEmpty()
    }

    @Test
    fun `getProfilePhotoUrls handles single member correctly`() {
        // Given
        val member = TestData.member
        val attachment = createProfileAttachment(member.id!!)

        // When
        val result = profilePhotoService.getProfilePhotoUrls(listOf(member.id!!))

        // Then
        assertThat(result).hasSize(1)
        assertThat(result[member.id]).isEqualTo("/api/attachments/${attachment.id}/thumbnail")
    }

    @Test
    fun `getProfilePhotoUrls returns correct result when all members have no profile photos`() {
        // Given
        val member1 = TestData.member
        val member2 = TestData.member2

        // When
        val result = profilePhotoService.getProfilePhotoUrls(listOf(member1.id!!, member2.id!!))

        // Then
        assertThat(result).hasSize(2)
        assertThat(result[member1.id]).isNull()
        assertThat(result[member2.id]).isNull()
    }

    private fun createProfileAttachment(memberId: Long): Attachment {
        val storedFilename = UUID.randomUUID().toString() + ".jpg"
        val attachment = Attachment(
            contextType = AttachmentContextType.PROFILE,
            contextId = memberId.toString(),
            originalFilename = "profile.jpg",
            storedFilename = storedFilename,
            contentType = "image/jpeg",
            size = 1024L,
            storagePath = "profile/$storedFilename",
            createdBy = memberId,
            orderIndex = 0
        )
        return attachmentRepository.save(attachment)
    }
}
