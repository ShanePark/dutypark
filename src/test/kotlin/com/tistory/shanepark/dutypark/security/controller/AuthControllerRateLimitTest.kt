package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultHandlers.print
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@AutoConfigureMockMvc
class AuthControllerRateLimitTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    @BeforeEach
    fun cleanup() {
        loginAttemptRepository.deleteAll()
    }

    @Test
    fun `login with wrong password returns unified error message with remaining attempts`() {
        val loginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.login.failed"))
            .andExpect(jsonPath("$.details.remainingAttempts").value(4))
            .andDo(print())
    }

    @Test
    fun `login with non-existent email returns same unified error message`() {
        val loginDto = LoginDto("nonexistent@email.com", "anypassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.login.failed"))
            .andExpect(jsonPath("$.details.remainingAttempts").value(4))
            .andDo(print())
    }

    @Test
    fun `login error message follows accept language`() {
        val loginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            post("/api/auth/token")
                .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.login.failed"))
            .andExpect(jsonPath("$.details.remainingAttempts").value(4))
            .andDo(print())
    }

    @Test
    fun `remaining attempts decrease with each failed login`() {
        val loginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.details.remainingAttempts").value(4))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.details.remainingAttempts").value(3))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.details.remainingAttempts").value(2))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.details.remainingAttempts").value(1))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.details.remainingAttempts").value(0))
    }

    @Test
    fun `after 5 failed attempts, login is blocked with 429 status`() {
        val loginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        repeat(5) {
            mockMvc.perform(
                post("/api/auth/token")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(json)
            ).andExpect(status().isUnauthorized)
        }

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isTooManyRequests)
            .andExpect(jsonPath("$.code").value("auth.login.rateLimited"))
            .andDo(print())
    }

    @Test
    fun `rate limit message follows accept language`() {
        val loginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        repeat(5) {
            mockMvc.perform(
                post("/api/auth/token")
                    .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(json)
            ).andExpect(status().isUnauthorized)
        }

        mockMvc.perform(
            post("/api/auth/token")
                .header(HttpHeaders.ACCEPT_LANGUAGE, "en")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isTooManyRequests)
            .andExpect(jsonPath("$.code").value("auth.login.rateLimited"))
            .andDo(print())
    }

    @Test
    fun `rate limit is per IP and email combination - different email works`() {
        val loginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val json = objectMapper.writeValueAsString(loginDto)

        repeat(5) {
            mockMvc.perform(
                post("/api/auth/token")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(json)
            ).andExpect(status().isUnauthorized)
        }

        val differentEmailDto = LoginDto(TestData.member2.email, "wrongpassword", false)
        val differentJson = objectMapper.writeValueAsString(differentEmailDto)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(differentJson)
        )
            .andExpect(status().isUnauthorized)
            .andDo(print())
    }

    @Test
    fun `correct credentials still blocked when rate limited`() {
        val wrongLoginDto = LoginDto(TestData.member.email, "wrongpassword", false)
        val wrongJson = objectMapper.writeValueAsString(wrongLoginDto)

        repeat(5) {
            mockMvc.perform(
                post("/api/auth/token")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(wrongJson)
            ).andExpect(status().isUnauthorized)
        }

        val correctLoginDto = LoginDto(TestData.member.email, TestData.testPass, false)
        val correctJson = objectMapper.writeValueAsString(correctLoginDto)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(correctJson)
        )
            .andExpect(status().isTooManyRequests)
            .andDo(print())
    }

    @Test
    fun `successful login is not affected by previous rate limiting for different email`() {
        val wrongEmailDto = LoginDto("other@email.com", "wrongpassword", false)
        val wrongJson = objectMapper.writeValueAsString(wrongEmailDto)

        repeat(5) {
            mockMvc.perform(
                post("/api/auth/token")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content(wrongJson)
            ).andExpect(status().isUnauthorized)
        }

        val correctLoginDto = LoginDto(TestData.member.email, TestData.testPass, false)
        val correctJson = objectMapper.writeValueAsString(correctLoginDto)

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(correctJson)
        )
            .andExpect(status().isOk)
            .andDo(print())
    }

}
