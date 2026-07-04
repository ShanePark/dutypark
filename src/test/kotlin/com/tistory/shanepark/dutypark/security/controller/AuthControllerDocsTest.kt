package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import jakarta.servlet.http.Cookie
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.JsonFieldType
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class AuthControllerDocsTest : RestDocsTest() {

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Test
    fun `refresh token`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/refresh")
                .cookie(Cookie("refresh_token", refreshToken.token))
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/refresh",
                    responseFields(
                        fieldWithPath("expiresIn").type(JsonFieldType.NUMBER)
                            .description("Access token expiration time in seconds")
                    )
                )
            )
    }

    @Test
    fun `refresh token unauthorized`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/refresh")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.status").value(401))
            .andExpect(jsonPath("$.code").value("auth.refresh.invalid"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/refresh-unauthorized",
                    responseFields(
                        fieldWithPath("status").type(JsonFieldType.NUMBER).description("HTTP status code"),
                        fieldWithPath("code").type(JsonFieldType.STRING)
                            .description("Machine-readable error code (`auth.refresh.invalid`, `auth.refresh.expired`)"),
                        fieldWithPath("details").type(JsonFieldType.OBJECT).optional().description("Additional error details"),
                        fieldWithPath("fieldErrors").type(JsonFieldType.ARRAY).optional().description("Field validation errors")
                    )
                )
            )
    }

    @Test
    fun `logout with refresh token only`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/logout")
                .cookie(Cookie("refresh_token", refreshToken.token))
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isNoContent)
            .andExpect(cookie().maxAge("access_token", 0))
            .andExpect(cookie().maxAge("refresh_token", 0))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/logout"
                )
            )
    }
}
