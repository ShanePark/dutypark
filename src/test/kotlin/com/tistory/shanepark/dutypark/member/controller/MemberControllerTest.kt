package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.nio.file.Files
import java.nio.file.Path
import javax.imageio.ImageIO
import java.awt.image.BufferedImage

class MemberControllerTest : RestDocsTest() {

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
    fun updateCalendarVisibility() {
        // Given
        val member = TestData.member
        assertThat(member.calendarVisibility).isEqualTo(Visibility.FRIENDS)

        // When
        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/${member.id}/visibility")
                .accept("application/json")
                .contentType("application/json")
                .content("{\"visibility\": \"PRIVATE\"}")
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "members/update-visibility",
                    requestFields(
                        fieldWithPath("visibility").description("Calendar visibility")
                    )
                )
            )

        // Then
        val findMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(findMember.calendarVisibility).isEqualTo(Visibility.PRIVATE)
    }

    @Test
    fun `getProfilePhoto returns cache-control header for long-term caching`() {
        // Given
        val member = TestData.member
        val profileDir = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}")
        createdDirectories.add(profileDir)
        Files.createDirectories(profileDir)

        val photoFilename = "test-photo.png"
        val photoPath = profileDir.resolve(photoFilename)
        createTestPngImage(photoPath)

        member.profilePhotoPath = "PROFILE/${member.id}/$photoFilename"
        memberRepository.save(member)
        em.flush()

        // When & Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/profile-photo")
        )
            .andExpect(status().isOk)
            .andExpect(header().exists(HttpHeaders.CACHE_CONTROL))
            .andExpect(header().string(HttpHeaders.CACHE_CONTROL, "max-age=31536000, public"))
            .andDo(MockMvcResultHandlers.print())
    }

    @Test
    fun `getProfilePhoto returns 404 when no photo exists`() {
        // Given
        val member = TestData.member
        member.profilePhotoPath = null
        memberRepository.save(member)

        // When & Then
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/profile-photo")
        )
            .andExpect(status().isNotFound)
    }

    private fun createTestPngImage(path: Path) {
        val image = BufferedImage(100, 100, BufferedImage.TYPE_INT_ARGB)
        val graphics = image.createGraphics()
        graphics.fillRect(0, 0, 100, 100)
        graphics.dispose()
        ImageIO.write(image, "png", path.toFile())
    }

}
