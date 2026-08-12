package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenResponse
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.cookieDomainWebCallbackUri
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
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
import java.util.Base64

@AutoConfigureMockMvc
@Import(MobileOAuthWebAccountDeletionControllerTest.ProviderApiTestConfig::class)
@TestPropertySource(
    properties = [
        "cookie.domain=app.dutypark.example",
    ]
)
class MobileOAuthWebAccountDeletionControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Test
    fun `allowlisted web callback completes PKCE exchange once without setting auth cookies`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID.toString())
        )
        val verifier = "w".repeat(43)
        val accessCookie = Cookie("access_token", getJwt(member))
        val state = authorize(WEB_CALLBACK, verifier, cookie = accessCookie)

        val callback = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, org.hamcrest.Matchers.startsWith("$WEB_CALLBACK?code=")))
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))
            .andReturn().response.getHeader(HttpHeaders.LOCATION)!!

        assertThat(callback).doesNotContain("reauthProof", "access_token", "refresh_token", "socialId")
        val exchangeCode = URI.create(callback).queryParam("code")

        mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.state.invalid"))

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(exchangeBody(exchangeCode, "x".repeat(43), WEB_CALLBACK))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.pkce.invalid"))

        val exchangeBody = exchangeBody(exchangeCode, verifier, WEB_CALLBACK)
        mockMvc.perform(
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

        mockMvc.perform(
            post("/api/auth/mobile/oauth/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(exchangeBody)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.code.invalid"))
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            "https://evil.example/auth/account-deletion-oauth-callback",
            "https://app.dutypark.example/auth/different",
            "https://app.dutypark.example/auth/account-deletion-oauth-callback?next=evil",
            "https://app.dutypark.example/auth/account-deletion-oauth-callback#fragment",
            "https://user@app.dutypark.example/auth/account-deletion-oauth-callback",
            "http://app.dutypark.example/auth/account-deletion-oauth-callback",
        ]
    )
    fun `delete account rejects callbacks outside exact web allowlist`(callbackUri: String) {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(authorizeBody("DELETE_ACCOUNT", callbackUri, "r".repeat(43)))
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.callback.notAllowed"))
    }

    @Test
    fun `login and link remain native callback only`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        listOf("LOGIN", "LINK").forEach { purpose ->
            val request = post("/api/auth/mobile/oauth/authorize")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(authorizeBody(purpose, WEB_CALLBACK, "n".repeat(43)))
            mockMvc.perform(request)
                .andExpect(status().isBadRequest)
                .andExpect(jsonPath("$.code").value("auth.oauth.mobile.callback.notAllowed"))
        }
    }

    @Test
    fun `web delete account authorize requires a real non-impersonated session`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .contentType(MediaType.APPLICATION_JSON)
                .content(authorizeBody("DELETE_ACCOUNT", WEB_CALLBACK, "u".repeat(43)))
        )
            .andExpect(status().isUnauthorized)

        val impersonationToken = jwtProvider.createImpersonationToken(TestData.member, TestData.admin.id!!)
        mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $impersonationToken")
                .contentType(MediaType.APPLICATION_JSON)
                .content(authorizeBody("DELETE_ACCOUNT", WEB_CALLBACK, "i".repeat(43)))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.code").value("auth.reauth.impersonationForbidden"))
    }

    @Test
    fun `web callback redirects account mismatch as a safe error only`() {
        val authenticatedMember = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val differentMember = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(differentMember, SsoType.KAKAO, KAKAO_ID.toString())
        )
        val state = authorize(WEB_CALLBACK, "m".repeat(43), bearer = getJwt(authenticatedMember))

        val location = mockMvc.perform(
            get("/api/auth/mobile/oauth/callback/kakao")
                .param("code", "provider-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(
                header().string(
                    HttpHeaders.LOCATION,
                    "$WEB_CALLBACK?error=reauth_account_mismatch",
                )
            )
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))
            .andReturn().response.getHeader(HttpHeaders.LOCATION)!!

        assertThat(location).doesNotContain("code=", "proof", "token", "socialId")
    }

    private fun authorize(
        callbackUri: String,
        verifier: String,
        bearer: String? = null,
        cookie: Cookie? = null,
    ): String {
        val request = post("/api/auth/mobile/oauth/authorize")
            .contentType(MediaType.APPLICATION_JSON)
            .content(authorizeBody("DELETE_ACCOUNT", callbackUri, verifier))
        bearer?.let { request.header(HttpHeaders.AUTHORIZATION, "Bearer $it") }
        if (cookie != null) {
            request.cookie(cookie)
        }
        val authorizationUrl = mockMvc.perform(request)
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.authorizationUrl").isString)
            .andReturn().response.contentAsString
            .let { objectMapper.readTree(it)["authorizationUrl"].stringValue() }
        return URI.create(authorizationUrl).queryParam("state")
    }

    private fun authorizeBody(purpose: String, callbackUri: String, verifier: String): String =
        objectMapper.writeValueAsString(
            mapOf(
                "provider" to "KAKAO",
                "purpose" to purpose,
                "callbackUri" to callbackUri,
                "codeChallenge" to challenge(verifier),
            )
        )

    private fun exchangeBody(code: String, verifier: String, callbackUri: String): String =
        objectMapper.writeValueAsString(
            mapOf(
                "code" to code,
                "codeVerifier" to verifier,
                "callbackUri" to callbackUri,
            )
        )

    private fun challenge(verifier: String): String = Base64.getUrlEncoder().withoutPadding().encodeToString(
        MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII))
    )

    private fun URI.queryParam(name: String): String = rawQuery.split('&')
        .map { it.split('=', limit = 2) }
        .first { it[0] == name }[1]

    @TestConfiguration
    class ProviderApiTestConfig {
        @Bean
        @Primary
        fun webAccountDeletionKakaoTokenApi(): KakaoTokenApi = object : KakaoTokenApi {
            override fun getAccessToken(
                grantType: String,
                clientId: String,
                redirectUri: String,
                code: String,
            ) = KakaoTokenResponse("token", "bearer", "refresh", 3600, 7200)
        }

        @Bean
        @Primary
        fun webAccountDeletionKakaoUserInfoApi(): KakaoUserInfoApi = object : KakaoUserInfoApi {
            override fun getUserInfo(accessToken: String) =
                KakaoUserInfoResponse(KAKAO_ID, "2026-08-13T00:00:00Z")
        }
    }

    companion object {
        private const val KAKAO_ID = 987654321L
        private const val WEB_CALLBACK =
            "https://app.dutypark.example/auth/account-deletion-oauth-callback"
    }
}

@AutoConfigureMockMvc
@TestPropertySource(
    properties = [
        "cookie.domain=dutypark.o-r.kr",
    ]
)
class MobileOAuthCookieDomainCallbackIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Test
    fun `cookie domain automatically allows the same-host HTTPS callback`() {
        authorizeDeleteAccount("https://dutypark.o-r.kr/auth/account-deletion-oauth-callback")
    }

    @Test
    fun `local callback remains allowed when optional extra origins are blank`() {
        authorizeDeleteAccount("http://localhost:5173/auth/account-deletion-oauth-callback")
    }

    private fun authorizeDeleteAccount(callbackUri: String) {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val verifier = "d".repeat(43)
        val challenge = Base64.getUrlEncoder().withoutPadding().encodeToString(
            MessageDigest.getInstance("SHA-256").digest(verifier.toByteArray(StandardCharsets.US_ASCII))
        )
        mockMvc.perform(
            post("/api/auth/mobile/oauth/authorize")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    objectMapper.writeValueAsString(
                        mapOf(
                            "provider" to "KAKAO",
                            "purpose" to "DELETE_ACCOUNT",
                            "callbackUri" to callbackUri,
                            "codeChallenge" to challenge,
                        )
                    )
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.authorizationUrl").isString)
    }
}

class MobileOAuthCookieDomainValidationTest {

    @Test
    fun `leading and trailing dots are normalized`() {
        assertThat(cookieDomainWebCallbackUri(".Dutypark.O-R.Kr."))
            .isEqualTo("https://dutypark.o-r.kr/auth/account-deletion-oauth-callback")
    }

    @Test
    fun `blank cookie domain adds no production callback`() {
        assertThat(cookieDomainWebCallbackUri("   ")).isNull()
    }

    @ParameterizedTest
    @ValueSource(
        strings = [
            "https://dutypark.o-r.kr",
            "dutypark.o-r.kr/path",
            "dutypark.o-r.kr:443",
            "user@dutypark.o-r.kr",
            "dutypark.o-r.kr?query",
            "dutypark.o-r.kr#fragment",
            "dutypark .o-r.kr",
            "dutypark_o-r.kr",
            "-dutypark.o-r.kr",
            "dutypark..o-r.kr",
            "127.0.0.1",
        ]
    )
    fun `malicious or non-DNS cookie domains fail fast`(domain: String) {
        assertThrows<IllegalStateException> {
            cookieDomainWebCallbackUri(domain)
        }
    }
}
