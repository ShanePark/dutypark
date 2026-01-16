package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

class RefreshTokenControllerTest : RestDocsTest() {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Test
    fun `get refresh tokens returns only valid tokens and marks current login`() {
        val expired = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        expired.validUntil = fixedDateTime.minusDays(1)
        refreshTokenRepository.save(expired)

        val current = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/refresh-tokens")
                .accept(MediaType.APPLICATION_JSON)
                .cookie(Cookie(CookieService.REFRESH_TOKEN_COOKIE, current.token))
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(1))
            .andExpect(jsonPath("$[0].token").value(current.token))
            .andExpect(jsonPath("$[0].isCurrentLogin").value(true))
    }

    @Test
    fun `get refresh tokens with validOnly false returns expired tokens`() {
        val expired = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        expired.validUntil = fixedDateTime.minusDays(1)
        refreshTokenRepository.save(expired)

        val current = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/refresh-tokens")
                .param("validOnly", "false")
                .accept(MediaType.APPLICATION_JSON)
                .cookie(Cookie(CookieService.REFRESH_TOKEN_COOKIE, current.token))
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(2))
            .andExpect(jsonPath("$[0].token").value(current.token))
            .andExpect(jsonPath("$[0].isCurrentLogin").value(true))
    }

    @Test
    fun `delete refresh token removes token for owner`() {
        val token = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/auth/refresh-tokens/{id}", token.id)
                .withAuth(TestData.member)
        )
            .andExpect(status().isNoContent)

        assertThat(refreshTokenRepository.findById(token.id!!)).isEmpty
    }

    @Test
    fun `delete refresh token fails for non-owner`() {
        val token = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/auth/refresh-tokens/{id}", token.id)
                .withAuth(TestData.member2)
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `delete other refresh tokens removes all except current`() {
        val current = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        val other = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/auth/refresh-tokens/others")
                .cookie(Cookie(CookieService.REFRESH_TOKEN_COOKIE, current.token))
                .withAuth(TestData.member)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.deletedCount").value(1))

        assertThat(refreshTokenRepository.findById(current.id!!)).isPresent
        assertThat(refreshTokenRepository.findById(other.id!!)).isEmpty
    }

    @Test
    fun `delete other refresh tokens returns bad request without current cookie`() {
        refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.delete("/api/auth/refresh-tokens/others")
                .withAuth(TestData.member)
        )
            .andExpect(status().isBadRequest)
    }
}
