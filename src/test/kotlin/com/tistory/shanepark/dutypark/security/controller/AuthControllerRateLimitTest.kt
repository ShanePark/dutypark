package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.autoconfigure.web.servlet.AutoConfigureMockMvc
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
            .andExpect(jsonPath("$.error").value("이메일 또는 비밀번호가 올바르지 않습니다."))
            .andExpect(jsonPath("$.remainingAttempts").value(4))
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
            .andExpect(jsonPath("$.error").value("이메일 또는 비밀번호가 올바르지 않습니다."))
            .andExpect(jsonPath("$.remainingAttempts").value(4))
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
            .andExpect(jsonPath("$.remainingAttempts").value(4))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.remainingAttempts").value(3))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.remainingAttempts").value(2))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.remainingAttempts").value(1))

        mockMvc.perform(
            post("/api/auth/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.remainingAttempts").value(0))
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
            .andExpect(jsonPath("$.error").value("로그인 시도 횟수를 초과했습니다. 잠시 후 다시 시도해 주세요."))
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
