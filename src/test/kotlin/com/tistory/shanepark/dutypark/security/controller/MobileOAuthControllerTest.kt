package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenResponse
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoResponse
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverTokenApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverTokenResponse
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoPayload
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoResponse
import org.assertj.core.api.Assertions.assertThat
import org.hamcrest.Matchers.startsWith
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.boot.test.context.TestConfiguration
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
import java.net.URLDecoder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.util.Base64

@AutoConfigureMockMvc
@Import(MobileOAuthControllerTest.ProviderApiTestConfig::class)
class MobileOAuthControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Test
    fun `kakao mobile oauth exchanges one-time code for existing member cookies`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID.toString())
        )
        val verifier = "a".repeat(43)
        val authorizationUrl = authorize("KAKAO", verifier)
        val providerUri = URI.create(authorizationUrl)
        val state = providerUri.queryParam("state")

        val callback = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andReturn().response.getHeader(HttpHeaders.LOCATION)!!

        assertThat(callback).startsWith("dutypark://oauth/callback?code=")
        assertThat(callback).doesNotContain("access_token", "refresh_token")
        val exchangeCode = URI.create(callback).queryParam("code")

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.state.invalid"))

        val body = """{"code":"$exchangeCode","codeVerifier":"$verifier","callbackUri":"dutypark://oauth/callback"}"""
        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(false))
            .andExpect(jsonPath("$.expiresIn").isNumber)
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(body)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.code.invalid"))
    }

    @Test
    fun `kakao mobile oauth preserves forwarded production callback uri through token exchange`() {
        val verifier = "i".repeat(43)
        val request = post("/api/auth/mobile/oauth/authorize")
            .header("X-Forwarded-Proto", "https")
            .header("X-Forwarded-Host", "dutypark.o-r.kr")
            .contentType(MediaType.APPLICATION_JSON)
            .content(
                """{"provider":"KAKAO","purpose":"LOGIN","callbackUri":"dutypark://oauth/callback","codeChallenge":"${challenge(verifier)}"}"""
            )
        val authorizationUrl = mockMvc.perform(request)
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.authorizationUrl").isString)
            .andReturn().response.contentAsString
            .let { Regex("\\\"authorizationUrl\\\":\\\"([^\\\"]+)\\\"").find(it)!!.groupValues[1] }
        val providerUri = URI.create(authorizationUrl)
        val state = providerUri.queryParam("state")

        assertThat(providerUri.decodedQueryParam("redirect_uri"))
            .isEqualTo(PRODUCTION_KAKAO_CALLBACK_URI)

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .header("X-Forwarded-Proto", "https")
                .header("X-Forwarded-Host", "dutypark.o-r.kr")
                .param("code", "forwarded-provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, startsWith("dutypark://oauth/callback?code=")))
    }

    @Test
    fun `naver mobile oauth preserves signup flow without setting token cookies`() {
        val verifier = "b".repeat(43)
        val authorizationUrl = authorize("NAVER", verifier)
        val state = URI.create(authorizationUrl).queryParam("state")

        val callback = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/naver")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andReturn().response.getHeader(HttpHeaders.LOCATION)!!
        val exchangeCode = URI.create(callback).queryParam("code")

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"code":"$exchangeCode","codeVerifier":"$verifier","callbackUri":"dutypark://oauth/callback"}"""
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(true))
            .andExpect(jsonPath("$.signupUuid").isString)
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))
    }

    @Test
    fun `mobile oauth rejects an unregistered app callback`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"provider":"KAKAO","callbackUri":"evilapp://oauth/callback","codeChallenge":"${challenge("c".repeat(43))}"}"""
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.callback.notAllowed"))
    }

    @Test
    fun `mobile oauth rejects wrong PKCE verifier and consumes nothing`() {
        val verifier = "d".repeat(43)
        val state = URI.create(authorize("KAKAO", verifier)).queryParam("state")
        val callback = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        ).andReturn().response.getHeader(HttpHeaders.LOCATION)!!
        val exchangeCode = URI.create(callback).queryParam("code")

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"code":"$exchangeCode","codeVerifier":"${"e".repeat(43)}","callbackUri":"dutypark://oauth/callback"}"""
                )
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.pkce.invalid"))

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"code":"$exchangeCode","codeVerifier":"$verifier","callbackUri":"dutypark://oauth/callback"}"""
                )
        )
            .andExpect(status().isOk)
    }

    @Test
    fun `mobile oauth links provider to authenticated member without exchanging login cookies`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val verifier = "f".repeat(43)
        val authorizationUrl = authorize(
            provider = "KAKAO",
            verifier = verifier,
            purpose = "LINK",
            bearer = getJwt(member),
        )
        val state = URI.create(authorizationUrl).queryParam("state")

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "dutypark://oauth/callback?linked=success"))
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))

        em.flush()
        em.clear()
        val linked = memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, KAKAO_ID.toString())
        assertThat(linked?.member?.id).isEqualTo(member.id)
    }

    @Test
    fun `mobile oauth link requires an authenticated member`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"provider":"KAKAO","purpose":"LINK","callbackUri":"dutypark://oauth/callback","codeChallenge":"${challenge("g".repeat(43))}"}"""
                )
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.unauthorized"))
    }

    @Test
    fun `mobile oauth redirects provider failure to the app and consumes state`() {
        val verifier = "h".repeat(43)
        val state = URI.create(authorize("KAKAO", verifier)).queryParam("state")

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-failure")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "dutypark://oauth/callback?error=provider_failed"))

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.state.invalid"))
    }

    private fun authorize(
        provider: String,
        verifier: String,
        purpose: String = "LOGIN",
        bearer: String? = null,
    ): String {
        val request = post("/api/auth/mobile/oauth/authorize")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"provider":"$provider","purpose":"$purpose","callbackUri":"dutypark://oauth/callback","codeChallenge":"${challenge(verifier)}"}"""
                )
        bearer?.let { request.header(HttpHeaders.AUTHORIZATION, "Bearer $it") }
        return mockMvc.perform(request)
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.authorizationUrl").isString)
            .andReturn().response.contentAsString
            .let { Regex("\\\"authorizationUrl\\\":\\\"([^\\\"]+)\\\"").find(it)!!.groupValues[1] }
    }

    private fun challenge(verifier: String): String = Base64.getUrlEncoder().withoutPadding().encodeToString(
        MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII))
    )

    private fun URI.queryParam(name: String): String = rawQuery.split('&')
        .map { it.split('=', limit = 2) }
        .first { it[0] == name }[1]

    private fun URI.decodedQueryParam(name: String): String =
        URLDecoder.decode(queryParam(name), StandardCharsets.UTF_8)

    @TestConfiguration
    class ProviderApiTestConfig {
        @Bean
        @Primary
        fun mobileTestKakaoTokenApi(): KakaoTokenApi = object : KakaoTokenApi {
            override fun getAccessToken(
                grantType: String,
                clientId: String,
                redirectUri: String,
                code: String
            ): KakaoTokenResponse {
                if (code == "provider-failure") {
                    throw IllegalStateException("provider failed")
                }
                if (code == "forwarded-provider-code") {
                    check(redirectUri == PRODUCTION_KAKAO_CALLBACK_URI)
                }
                return KakaoTokenResponse("token", "bearer", "refresh", 3600, 7200)
            }
        }

        @Bean
        @Primary
        fun mobileTestKakaoUserInfoApi(): KakaoUserInfoApi = object : KakaoUserInfoApi {
            override fun getUserInfo(accessToken: String) = KakaoUserInfoResponse(KAKAO_ID, "2025-01-01T00:00:00Z")
        }

        @Bean
        @Primary
        fun mobileTestNaverTokenApi(): NaverTokenApi = object : NaverTokenApi {
            override fun getAccessToken(
                grantType: String,
                clientId: String,
                clientSecret: String,
                code: String,
                state: String
            ) = NaverTokenResponse(
                accessToken = "token",
                refreshToken = "refresh",
                tokenType = "bearer",
                expiresIn = "3600"
            )
        }

        @Bean
        @Primary
        fun mobileTestNaverUserInfoApi(): NaverUserInfoApi = object : NaverUserInfoApi {
            override fun getUserInfo(accessToken: String) = NaverUserInfoResponse(
                resultCode = "00",
                message = "success",
                response = NaverUserInfoPayload(NAVER_ID)
            )
        }
    }

    companion object {
        private const val KAKAO_ID = 987654321L
        private const val NAVER_ID = "mobile-naver-id"
        private const val PRODUCTION_KAKAO_CALLBACK_URI =
            "https://dutypark.o-r.kr/api/auth/mobile/oauth/callback/kakao"
    }
}
