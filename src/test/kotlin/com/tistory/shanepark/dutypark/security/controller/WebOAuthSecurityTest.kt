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
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthPurpose
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthTransaction
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthTransactionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.mock.web.MockHttpSession
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.web.util.UriComponentsBuilder
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Clock

@AutoConfigureMockMvc
@Import(WebOAuthSecurityTest.ProviderApiTestConfig::class)
class WebOAuthSecurityTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var socialAccountRepository: MemberSocialAccountRepository

    @Autowired
    lateinit var webOAuthTransactionRepository: WebOAuthTransactionRepository

    @Autowired
    lateinit var clock: Clock

    @Autowired
    lateinit var providerCalls: ProviderCalls

    @Test
    fun `server issues opaque kakao state and completes login once in the initiating session`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        socialAccountRepository.saveAndFlush(MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID))
        val flow = authorize("KAKAO", "LOGIN", "/todo?view=mine")

        assertThat(flow.authorizationUrl).startsWith("https://kauth.kakao.com/oauth/authorize?")
        assertThat(flow.state).matches("^[A-Za-z0-9_-]{43}$")
        assertThat(flow.authorizationUrl).doesNotContain("callbackUrl", "referer", "%2Ftodo")

        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/kakao")
                .session(flow.session)
                .param("code", "test-code")
                .param("state", flow.state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "$CALLBACK_URL#login=success&redirect=%2Ftodo%3Fview%3Dmine"))
            .andExpect(cookie().exists("access_token"))

        callback(flow, "kakao")
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))
    }

    @Test
    fun `server issues opaque naver state and completes login in the initiating session`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        socialAccountRepository.saveAndFlush(MemberSocialAccount(member, SsoType.NAVER, NAVER_ID))
        val flow = authorize("NAVER", "LOGIN", "/")

        assertThat(flow.authorizationUrl).startsWith("https://nid.naver.com/oauth2.0/authorize?")
        assertThat(flow.state).matches("^[A-Za-z0-9_-]{43}$")

        callback(flow, "naver")
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "$CALLBACK_URL#login=success&redirect=%2F"))
            .andExpect(cookie().exists("access_token"))

        callback(flow, "naver")
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))
    }

    @Test
    fun `callback rejects forged provider and different browser session without external redirect`() {
        val flow = authorize("KAKAO", "LOGIN", "/member")

        callback(flow, "naver")
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))

        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/kakao")
                .session(MockHttpSession())
                .param("code", "test-code")
                .param("state", flow.state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))
    }

    @Test
    fun `link callback requires the same authenticated member that initiated it`() {
        val initiatingMember = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val otherMember = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        val flow = authorize("KAKAO", "LINK", "/member", getJwt(initiatingMember))

        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/kakao")
                .session(flow.session)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(otherMember)}")
                .param("code", "test-code")
                .param("state", flow.state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))

        assertThat(socialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, KAKAO_ID)).isNull()

        val naverFlow = authorize("NAVER", "LINK", "/member", getJwt(initiatingMember))
        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/naver")
                .session(naverFlow.session)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(otherMember)}")
                .param("code", "test-code")
                .param("state", naverFlow.state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))

        assertThat(socialAccountRepository.findByProviderAndSocialId(SsoType.NAVER, NAVER_ID)).isNull()
    }

    @Test
    fun `link purpose cannot be initiated anonymously`() {
        mockMvc.perform(
            post("/api/auth/oauth2/authorize")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"NAVER","purpose":"LINK","referer":"/member"}""")
        )
            .andExpect(status().isUnauthorized)
    }

    @Test
    fun `authorize rejects external protocol relative backslash and encoded redirect bypasses`() {
        listOf("KAKAO", "NAVER").forEach { provider ->
            listOf(
                "https://evil.example/steal",
                "//evil.example/steal",
                "/\\evil.example/steal",
                "/%2fevil.example/steal",
                "/%255cevil.example/steal",
            ).forEach { referer ->
                mockMvc.perform(
                    post("/api/auth/oauth2/authorize")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(objectMapper.writeValueAsString(mapOf(
                            "provider" to provider,
                            "purpose" to "LOGIN",
                            "referer" to referer,
                        )))
                )
                    .andExpect(status().isBadRequest)
                    .andExpect(jsonPath("$.code").value("auth.oauth.web.referer.invalid"))
            }
        }
    }

    @Test
    fun `expired state redirects to the fixed internal callback error`() {
        val session = MockHttpSession()
        val state = "expired-web-oauth-state"
        webOAuthTransactionRepository.save(
            WebOAuthTransaction(
                provider = SsoType.NAVER,
                purpose = WebOAuthPurpose.LOGIN,
                referer = "/member",
                stateHash = sha256Hex(state),
                browserSessionHash = sha256Hex(session.id),
                stateExpiresAt = clock.instant().minusSeconds(1),
            )
        )

        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/naver")
                .session(session)
                .param("code", "test-code")
                .param("state", state)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))
    }

    @Test
    fun `forged state always redirects to the fixed internal callback error`() {
        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/kakao")
                .session(MockHttpSession())
                .param("code", "test-code")
                .param("state", "https://evil.example/steal")
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, INVALID_STATE_LOCATION))
    }

    @Test
    fun `configured callback URI ignores hostile host and forwarded headers for authorize and token exchange`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        socialAccountRepository.saveAndFlush(MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID))
        val authorizeResult = mockMvc.perform(
            post("/api/auth/oauth2/authorize")
                .header(HttpHeaders.HOST, "evil.example")
                .header("X-Forwarded-Host", "forwarded-evil.example")
                .header("X-Forwarded-Proto", "https")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"KAKAO","purpose":"LOGIN","referer":"/"}""")
        )
            .andExpect(status().isOk)
            .andReturn()
        val authorizationUrl = objectMapper.readTree(authorizeResult.response.contentAsString)["authorizationUrl"].asText()
        val authorizationParams = UriComponentsBuilder.fromUriString(authorizationUrl).build().queryParams
        assertThat(authorizationParams.getFirst("redirect_uri"))
            .isEqualTo("http://localhost:8080/api/auth/Oauth2ClientCallback/kakao")
        val state = authorizationParams.getFirst("state")!!

        mockMvc.perform(
            get("/api/auth/Oauth2ClientCallback/kakao")
                .session(authorizeResult.request.getSession(false) as MockHttpSession)
                .header(HttpHeaders.HOST, "evil.example")
                .header("X-Forwarded-Host", "forwarded-evil.example")
                .header("X-Forwarded-Proto", "https")
                .param("code", "test-code")
                .param("state", state)
        )
            .andExpect(status().isFound)

        assertThat(providerCalls.kakaoRedirectUri)
            .isEqualTo("http://localhost:8080/api/auth/Oauth2ClientCallback/kakao")
    }

    private fun authorize(
        provider: String,
        purpose: String,
        referer: String,
        jwt: String? = null,
    ): AuthorizedFlow {
        val request = post("/api/auth/oauth2/authorize")
            .contentType(MediaType.APPLICATION_JSON)
            .content(objectMapper.writeValueAsString(mapOf(
                "provider" to provider,
                "purpose" to purpose,
                "referer" to referer,
            )))
        if (jwt != null) request.header(HttpHeaders.AUTHORIZATION, "Bearer $jwt")
        val result = mockMvc.perform(request)
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").value(300))
            .andReturn()
        val authorizationUrl = objectMapper.readTree(result.response.contentAsString)["authorizationUrl"].asText()
        val state = UriComponentsBuilder.fromUriString(authorizationUrl).build().queryParams.getFirst("state")!!
        return AuthorizedFlow(result.request.getSession(false) as MockHttpSession, authorizationUrl, state)
    }

    private fun callback(flow: AuthorizedFlow, provider: String) = mockMvc.perform(
        get("/api/auth/Oauth2ClientCallback/$provider")
            .session(flow.session)
            .param("code", "test-code")
            .param("state", flow.state)
    )

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    data class AuthorizedFlow(
        val session: MockHttpSession,
        val authorizationUrl: String,
        val state: String,
    )

    @TestConfiguration
    class ProviderApiTestConfig {
        @Bean
        fun providerCalls() = ProviderCalls()

        @Bean
        @Primary
        fun webSecurityTestKakaoTokenApi(providerCalls: ProviderCalls): KakaoTokenApi = object : KakaoTokenApi {
            override fun getAccessToken(
                grantType: String,
                clientId: String,
                redirectUri: String,
                code: String,
            ): KakaoTokenResponse {
                providerCalls.kakaoRedirectUri = redirectUri
                return KakaoTokenResponse("access-token", "bearer", "refresh-token", 3600, 7200)
            }
        }

        @Bean
        @Primary
        fun webSecurityTestKakaoUserInfoApi(): KakaoUserInfoApi = object : KakaoUserInfoApi {
            override fun getUserInfo(accessToken: String) = KakaoUserInfoResponse(KAKAO_ID.toLong(), "2026-08-14")
        }

        @Bean
        @Primary
        fun webSecurityTestNaverTokenApi(): NaverTokenApi = object : NaverTokenApi {
            override fun getAccessToken(
                grantType: String,
                clientId: String,
                clientSecret: String,
                code: String,
                state: String,
            ) = NaverTokenResponse("access-token", "refresh-token", "bearer", "3600")
        }

        @Bean
        @Primary
        fun webSecurityTestNaverUserInfoApi(): NaverUserInfoApi = object : NaverUserInfoApi {
            override fun getUserInfo(accessToken: String) =
                NaverUserInfoResponse("00", "success", NaverUserInfoPayload(NAVER_ID))
        }
    }

    class ProviderCalls {
        var kakaoRedirectUri: String? = null
    }

    companion object {
        private const val KAKAO_ID = "918273645"
        private const val NAVER_ID = "naver-web-security-id"
        private const val CALLBACK_URL = "/auth/oauth-callback"
        private const val INVALID_STATE_LOCATION = "$CALLBACK_URL#error=oauth_state_invalid"
    }
}
