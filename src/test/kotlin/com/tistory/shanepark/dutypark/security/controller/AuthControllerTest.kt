package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import org.junit.jupiter.api.Test
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.restdocs.payload.PayloadDocumentation.*
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

class AuthControllerTest : RestDocsTest() {

    @Test
    fun `login with token returns access and refresh tokens`() {
        val json = """
            {
                "email": "${TestData.member.email}",
                "password": "${TestData.testPass}",
                "rememberMe": false
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/token")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.accessToken").exists())
            .andExpect(jsonPath("$.refreshToken").exists())
            .andExpect(jsonPath("$.expiresIn").exists())
            .andExpect(jsonPath("$.tokenType").value("Bearer"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/login-token",
                    requestFields(
                        fieldWithPath("email").description("User email address"),
                        fieldWithPath("password").description("User password"),
                        fieldWithPath("rememberMe").description("Remember me flag for extended session")
                    ),
                    responseFields(
                        fieldWithPath("accessToken").description("JWT access token for API authentication"),
                        fieldWithPath("refreshToken").description("Refresh token for obtaining new access tokens"),
                        fieldWithPath("expiresIn").description("Access token expiration time in seconds"),
                        fieldWithPath("tokenType").description("Token type (Bearer)")
                    )
                )
            )
    }

    @Test
    fun `login with token returns 401 for invalid credentials`() {
        val json = """
            {
                "email": "${TestData.member.email}",
                "password": "wrongpassword",
                "rememberMe": false
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/token")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/login-token-unauthorized",
                    requestFields(
                        fieldWithPath("email").description("User email address"),
                        fieldWithPath("password").description("User password"),
                        fieldWithPath("rememberMe").description("Remember me flag")
                    ),
                    responseFields(
                        fieldWithPath("error").description("Error message")
                    )
                )
            )
    }

    @Test
    fun `get login status returns user info when authenticated`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/auth/status")
                .accept(MediaType.APPLICATION_JSON)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.member.id))
            .andExpect(jsonPath("$.name").value(TestData.member.name))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/status",
                    responseFields(
                        fieldWithPath("id").description("User ID"),
                        fieldWithPath("email").description("User email"),
                        fieldWithPath("name").description("User name"),
                        fieldWithPath("teamId").description("Team ID (nullable)"),
                        fieldWithPath("team").description("Team name (nullable)"),
                        fieldWithPath("isAdmin").description("Admin flag")
                    )
                )
            )
    }

    @Test
    fun `get login status returns null when not authenticated`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/auth/status")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document("auth/status-unauthenticated")
            )
    }

    @Test
    fun `change password successfully`() {
        val json = """
            {
                "memberId": ${TestData.member.id},
                "currentPassword": "${TestData.testPass}",
                "newPassword": "newPassword123"
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.put("/api/auth/password")
                .accept(MediaType.APPLICATION_JSON)
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "auth/change-password",
                    requestFields(
                        fieldWithPath("memberId").description("Member ID whose password is being changed"),
                        fieldWithPath("currentPassword").description("Current password for verification"),
                        fieldWithPath("newPassword").description("New password to set")
                    )
                )
            )
    }

}
