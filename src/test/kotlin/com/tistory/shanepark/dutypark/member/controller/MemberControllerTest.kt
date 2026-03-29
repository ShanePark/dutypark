package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.content
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
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
    fun `get preferred locale`() {
        val member = TestData.member
        member.preferredLocale = "en"
        memberRepository.save(member)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/me/preferred-locale")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.preferredLocale").value("en"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "members/get-preferred-locale",
                    responseFields(
                        fieldWithPath("preferredLocale").description("Preferred locale code for the current member")
                    )
                )
            )
    }

    @Test
    fun `update preferred locale`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/preferred-locale")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"preferredLocale\": \"en\"}")
                .withAuth(member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.preferredLocale").value("en"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "members/update-preferred-locale",
                    requestFields(
                        fieldWithPath("preferredLocale").description("Preferred locale code to store (ko or en)")
                    ),
                    responseFields(
                        fieldWithPath("preferredLocale").description("Updated preferred locale code")
                    )
                )
            )

        val updatedMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updatedMember.preferredLocale).isEqualTo("en")
    }

    @Test
    fun `update preferred locale validates supported language in english`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/me/preferred-locale")
                .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content("{\"preferredLocale\": \"fr\"}")
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error").value("Preferred locale must be one of: ko, en."))
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

    @Test
    fun `updateCalendarVisibility fails for other member`() {
        val member = TestData.member
        val other = TestData.member2

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/members/${other.id}/visibility")
                .accept("application/json")
                .contentType("application/json")
                .content("{\"visibility\": \"PRIVATE\"}")
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
    }

    @Test
    fun `createAuxiliaryAccount returns 400 when name missing`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/members/auxiliary")
                .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
                .accept("application/json")
                .contentType("application/json")
                .content("{}")
                .withAuth(member)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error").value("Name is required."))
    }

    @Test
    fun `amIManager returns false when not logged in`() {
        val member = TestData.member

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}/canManage")
        )
            .andExpect(status().isOk)
            .andExpect(content().string("false"))
    }

    @Test
    fun `admin can get private member details`() {
        val member = TestData.member
        member.calendarVisibility = Visibility.PRIVATE
        memberRepository.save(member)

        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/members/${member.id}")
                .withAuth(TestData.admin)
        )
            .andExpect(status().isOk)
            .andExpect(content().string(org.hamcrest.Matchers.containsString(member.name)))
    }

    @Test
    fun `getProfilePhoto returns 404 when file is missing`() {
        val member = TestData.member
        val missingPath = storagePathResolver.getStorageRoot().resolve("PROFILE/${member.id}/missing.png")
        member.profilePhotoPath = "PROFILE/${member.id}/missing.png"
        memberRepository.save(member)
        createdDirectories.add(missingPath.parent)

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
