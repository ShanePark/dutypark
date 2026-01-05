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
