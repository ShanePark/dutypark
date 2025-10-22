package com.tistory.shanepark.dutypark.attachment.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.CreateSessionRequest
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders.post
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class AttachmentSessionControllerTest : RestDocsTest() {

    @Autowired
    lateinit var sessionRepository: AttachmentUploadSessionRepository

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
                .cookie(Cookie(jwtConfig.cookieName, jwt))
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

}
