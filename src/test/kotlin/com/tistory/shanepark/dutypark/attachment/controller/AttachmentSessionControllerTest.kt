package com.tistory.shanepark.dutypark.attachment.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.CreateSessionRequest
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.AfterEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.mock.web.MockMultipartFile
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.delete
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.post
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.restdocs.request.RequestDocumentation.parameterWithName
import org.springframework.restdocs.request.RequestDocumentation.pathParameters
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.nio.file.Files
import java.time.Clock

class AttachmentSessionControllerTest : RestDocsTest() {

    @Autowired
    lateinit var sessionRepository: AttachmentUploadSessionRepository

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Autowired
    lateinit var pathResolver: StoragePathResolver

    @Autowired
    lateinit var clock: Clock

    @AfterEach
    fun cleanup() {
        attachmentRepository.deleteAll()
        sessionRepository.deleteAll()
        val storageRoot = pathResolver.getStorageRoot()
        if (Files.exists(storageRoot)) {
            Files.walk(storageRoot)
                .sorted(Comparator.reverseOrder())
                .forEach { Files.deleteIfExists(it) }
        }
    }

    @Test
    fun `create session successfully`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val request = CreateSessionRequest(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null
        )
        val json = objectMapper.writeValueAsString(request)

        val sizeBefore = sessionRepository.count()

        mockMvc.perform(
            post("/api/attachments/sessions")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        ).andExpect(status().isOk)
            .andExpect(jsonPath("$.sessionId").exists())
            .andExpect(jsonPath("$.expiresAt").exists())
            .andExpect(jsonPath("$.contextType").value("SCHEDULE"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/sessions/create",
                    requestFields(
                        fieldWithPath("contextType").type(JsonFieldType.STRING).description("Context type for the upload session (e.g., SCHEDULE, PROFILE)"),
                        fieldWithPath("targetContextId").type(JsonFieldType.STRING).description("Optional target context ID when editing existing entity").optional()
                    ),
                    responseFields(
                        fieldWithPath("sessionId").type(JsonFieldType.STRING).description("Unique identifier for the upload session"),
                        fieldWithPath("expiresAt").type(JsonFieldType.STRING).description("Session expiration timestamp"),
                        fieldWithPath("contextType").type(JsonFieldType.STRING).description("Context type for this session")
                    )
                )
            )

        assertThat(sessionRepository.count()).isEqualTo(sizeBefore + 1)
    }

    @Test
    fun `create session unauthorized`() {
        val request = CreateSessionRequest(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = null
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            post("/api/attachments/sessions")
                .accept("application/json")
                .contentType("application/json")
                .content(json)
        ).andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/sessions/create-unauthorized",
                    responseFields(
                        fieldWithPath("errorCode").type(JsonFieldType.NUMBER).description("401"),
                        fieldWithPath("message").type(JsonFieldType.STRING).description("Error message")
                    )
                )
            )
    }

    @Test
    fun `discard session successfully deletes session and temporary files`() {
        val member = TestData.member
        val jwt = getJwt(member)

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member.id!!,
                expiresAt = clock.instant().plusSeconds(86400)
            )
        )

        val file = MockMultipartFile(
            "file",
            "test-discard.txt",
            "text/plain",
            "Test content for discard".toByteArray()
        )

        mockMvc.perform(
            multipart("/api/attachments")
                .file(file)
                .param("sessionId", session.id.toString())
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        ).andExpect(status().isOk)

        val tempDir = pathResolver.resolveTemporaryDirectory(session.id)
        assertThat(Files.exists(tempDir)).isTrue()
        assertThat(attachmentRepository.count()).isEqualTo(1)
        assertThat(sessionRepository.count()).isEqualTo(1)

        mockMvc.perform(
            delete("/api/attachments/sessions/{sessionId}", session.id)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        ).andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "attachments/sessions/discard",
                    pathParameters(
                        parameterWithName("sessionId").description("Session ID to discard")
                    )
                )
            )

        assertThat(sessionRepository.count()).isEqualTo(0)
        assertThat(attachmentRepository.count()).isEqualTo(0)
        assertThat(Files.exists(tempDir)).isFalse()
    }

    @Test
    fun `discard session unauthorized for another user's session`() {
        val member = TestData.member
        val member2 = TestData.member2
        val jwt = getJwt(member)

        val session = sessionRepository.save(
            AttachmentUploadSession(
                contextType = AttachmentContextType.SCHEDULE,
                targetContextId = null,
                ownerId = member2.id!!,
                expiresAt = clock.instant().plusSeconds(86400)
            )
        )

        mockMvc.perform(
            delete("/api/attachments/sessions/{sessionId}", session.id)
                .header(org.springframework.http.HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        ).andExpect(status().is4xxClientError)
            .andDo(MockMvcResultHandlers.print())

        assertThat(sessionRepository.count()).isEqualTo(1)
    }

}
