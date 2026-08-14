package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.time.AdjustableTestClock
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.reauth.ReauthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import java.net.URI
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.LocalDate
import java.time.ZoneOffset
import java.util.Base64

@AutoConfigureMockMvc
@Import(
    MobileOAuthControllerTest.ProviderApiTestConfig::class,
    MobileOAuthAccountDeletionControllerTest.TestClockConfig::class,
)
class MobileOAuthAccountDeletionControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Autowired
    lateinit var reauthService: ReauthService

    @Autowired
    lateinit var clock: AdjustableTestClock

    @BeforeEach
    fun resetClock() {
        clock.setDate(LocalDate.of(2026, 8, 12), ZoneOffset.UTC)
    }

    @Test
    fun `delete account oauth issues cookie-free one-time proof for the authenticated social account`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID.toString())
        )
        val verifier = "a".repeat(43)
        val state = authorizeDeleteAccount(verifier, getJwt(member))

        val callback = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))
            .andReturn().response.getHeader(HttpHeaders.LOCATION)!!
        val exchangeCode = URI.create(callback).queryParam("code")

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.state.invalid"))

        val exchangeBody = exchangeBody(exchangeCode, verifier)
        val proof = mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(exchangeBody)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(false))
            .andExpect(jsonPath("$.expiresIn").value(300))
            .andExpect(jsonPath("$.reauthProof").isNotEmpty)
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))
            .andReturn().response.contentAsString
            .let { objectMapper.readTree(it)["reauthProof"].stringValue() }

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(exchangeBody)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.code.invalid"))

        reauthService.consume(member.id!!, ReauthPurpose.DELETE_ACCOUNT, proof)
        val reused = assertThrows<AuthException> {
            reauthService.consume(member.id!!, ReauthPurpose.DELETE_ACCOUNT, proof)
        }
        assertThat(reused.message).isEqualTo("auth.reauth.proof.invalid")
    }

    @Test
    fun `delete account oauth rejects a different social account and consumes state`() {
        val authenticatedMember = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val differentMember = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(differentMember, SsoType.KAKAO, KAKAO_ID.toString())
        )
        val verifier = "b".repeat(43)
        val state = authorizeDeleteAccount(verifier, getJwt(authenticatedMember))

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(
                header().string(
                    HttpHeaders.LOCATION,
                    "dutypark://oauth/callback?error=reauth_account_mismatch",
                )
            )
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.state.invalid"))
    }

    @Test
    fun `delete account oauth preserves exchange after wrong PKCE and proof expires`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID.toString())
        )
        val verifier = "c".repeat(43)
        val state = authorizeDeleteAccount(verifier, getJwt(member))
        val callback = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        ).andReturn().response.getHeader(HttpHeaders.LOCATION)!!
        val exchangeCode = URI.create(callback).queryParam("code")

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(exchangeBody(exchangeCode, "d".repeat(43)))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.pkce.invalid"))

        val proof = mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(exchangeBody(exchangeCode, verifier))
        )
            .andExpect(status().isOk)
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))
            .andReturn().response.contentAsString
            .let { objectMapper.readTree(it)["reauthProof"].stringValue() }

        clock.setDate(LocalDate.of(2026, 8, 13), ZoneOffset.UTC)
        val expired = assertThrows<AuthException> {
            reauthService.consume(member.id!!, ReauthPurpose.DELETE_ACCOUNT, proof)
        }
        assertThat(expired.message).isEqualTo("auth.reauth.proof.invalid")
    }

    private fun authorizeDeleteAccount(verifier: String, bearer: String): String {
        val authorizationUrl = mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $bearer")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"provider":"KAKAO","purpose":"DELETE_ACCOUNT","callbackUri":"dutypark://oauth/callback","codeChallenge":"${challenge(verifier)}"}"""
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.authorizationUrl").isString)
            .andReturn().response.contentAsString
            .let { objectMapper.readTree(it)["authorizationUrl"].stringValue() }
        return URI.create(authorizationUrl).queryParam("state")
    }

    private fun exchangeBody(code: String, verifier: String): String =
        """{"code":"$code","codeVerifier":"$verifier","callbackUri":"dutypark://oauth/callback"}"""

    private fun challenge(verifier: String): String = Base64.getUrlEncoder().withoutPadding().encodeToString(
        MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII))
    )

    private fun URI.queryParam(name: String): String = rawQuery.split('&')
        .map { it.split('=', limit = 2) }
        .first { it[0] == name }[1]

    @TestConfiguration
    class TestClockConfig {
        @Bean
        @Primary
        fun adjustableAccountDeletionTestClock(): AdjustableTestClock = AdjustableTestClock()
    }

    companion object {
        private const val KAKAO_ID = 987654321L
    }
}
