package com.tistory.shanepark.dutypark.admin.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.time.LocalDateTime

@AutoConfigureMockMvc
class AdminControllerTest : DutyparkIntegrationTest() {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @Test
    fun `non-admin cannot access refresh token list`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/refresh-tokens")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.member)}")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `admin sees only valid refresh tokens`() {
        val validToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        val expiredToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member2.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        expiredToken.validUntil = fixedDateTime.minusDays(1)
        refreshTokenRepository.save(expiredToken)
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/refresh-tokens")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.length()").value(1))
            .andExpect(jsonPath("$[0].id").value(validToken.id))
    }

    @Test
    fun `admin can search members with keyword and sees valid tokens only`() {
        val validToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        val expiredToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "Test-Agent"
        )
        expiredToken.validUntil = fixedDateTime.minusDays(1)
        refreshTokenRepository.save(expiredToken)
        em.flush()
        em.clear()

        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/members")
                .param("keyword", TestData.member.name)
                .param("page", "0")
                .param("size", "10")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(1))
            .andExpect(jsonPath("$.content[0].id").value(TestData.member.id))
            .andExpect(jsonPath("$.content[0].name").value(TestData.member.name))
            .andExpect(jsonPath("$.content[0].tokens.length()").value(1))
            .andExpect(jsonPath("$.content[0].tokens[0].id").value(validToken.id))
    }

    @Test
    fun `admin search with unmatched keyword returns empty page`() {
        mockMvc.perform(
            MockMvcRequestBuilders.get("/admin/api/members")
                .param("keyword", "no-such-member")
                .param("page", "0")
                .param("size", "10")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(TestData.admin)}")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.content.length()").value(0))
            .andExpect(jsonPath("$.empty").value(true))
    }
}
