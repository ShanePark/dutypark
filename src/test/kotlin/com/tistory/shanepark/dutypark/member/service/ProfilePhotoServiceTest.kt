package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class ProfilePhotoServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var profilePhotoService: ProfilePhotoService

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
}
