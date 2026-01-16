package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberConsentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.SsoSignupRequest
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenResponse
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoResponse
import org.assertj.core.api.Assertions.assertThat
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
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.header
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@AutoConfigureMockMvc
@Import(OAuthControllerTest.KakaoApiTestConfig::class)
class OAuthControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberSsoRegisterRepository: MemberSsoRegisterRepository

    @Autowired
    lateinit var memberConsentRepository: MemberConsentRepository

    @Autowired
    lateinit var jwtConfig: JwtConfig

    @Test
    fun `kakao callback links kakao id when login requested`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        member.kakaoId = null

        val stateJson = stateJson(login = true, referer = "/after")

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/kakao")
                .param("code", "test-code")
                .param("state", stateJson)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "/after"))

        em.flush()
        em.clear()

        val updated = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(updated.kakaoId).isEqualTo(TEST_KAKAO_ID.toString())
    }

    @Test
    fun `kakao callback redirects with login success when member exists`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        member.kakaoId = TEST_KAKAO_ID.toString()
        memberRepository.save(member)

        val stateJson = stateJson(callbackUrl = CALLBACK_URL)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/kakao")
                .param("code", "test-code")
                .param("state", stateJson)
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "$CALLBACK_URL#login=success"))
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))

        assertThat(memberSsoRegisterRepository.findAll()).isEmpty()
    }

    @Test
    fun `kakao callback redirects with sso required when member not found`() {
        val stateJson = stateJson(callbackUrl = CALLBACK_URL)

        val result = mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/kakao")
                .param("code", "test-code")
                .param("state", stateJson)
        )
            .andExpect(status().isFound)
            .andReturn()

        val saved = memberSsoRegisterRepository.findAll().single()
        assertThat(saved.ssoType).isEqualTo(SsoType.KAKAO)
        assertThat(saved.ssoId).isEqualTo(TEST_KAKAO_ID.toString())

        val location = result.response.getHeader(HttpHeaders.LOCATION)
        assertThat(location).isEqualTo("$CALLBACK_URL#error=sso_required&uuid=${saved.uuid}")
    }

    @Test
    fun `kakao callback without callbackUrl returns bad request`() {
        val stateJson = stateJson(login = false)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/kakao")
                .param("code", "test-code")
                .param("state", stateJson)
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.error").value("callbackUrl is required in state"))
    }

    @Test
    fun `sso signup creates member and consent with default versions`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-1"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "new-user",
            termAgree = true,
            privacyAgree = true
        )

        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/sso/signup/token")
                .contentType(MediaType.APPLICATION_JSON)
                .header(HttpHeaders.USER_AGENT, "Test-UA")
                .with { it.remoteAddr = "127.0.0.1"; it }
                .content(json)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.expiresIn").value(jwtConfig.tokenValidityInSeconds))
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))

        val created = memberRepository.findAll().first { it.name == "new-user" }
        assertThat(created.password).isEqualTo("")
        assertThat(created.kakaoId).isEqualTo("kakao-id-1")

        val consents = memberConsentRepository.findAll().filter { it.member.id == created.id }
        assertThat(consents).hasSize(2)
        assertThat(consents.map { it.policyType }).containsExactlyInAnyOrder(PolicyType.TERMS, PolicyType.PRIVACY)

        consents.forEach { consent ->
            assertThat(consent.consentVersion).isEqualTo("2025-01-15")
            assertThat(consent.ipAddress).isEqualTo("127.0.0.1")
            assertThat(consent.userAgent).isEqualTo("Test-UA")
        }
    }

    @Test
    fun `sso signup returns bad request when term not agreed`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-2"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "bad-user-1",
            termAgree = false,
            privacyAgree = true
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/sso/signup/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)

        assertThat(memberRepository.findAll().none { it.name == "bad-user-1" }).isTrue
        assertThat(memberConsentRepository.findAll().none { it.member.name == "bad-user-1" }).isTrue
    }

    @Test
    fun `sso signup returns bad request when privacy not agreed`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-3"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "bad-user-2",
            termAgree = true,
            privacyAgree = false
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/sso/signup/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)

        assertThat(memberRepository.findAll().none { it.name == "bad-user-2" }).isTrue
        assertThat(memberConsentRepository.findAll().none { it.member.name == "bad-user-2" }).isTrue
    }

    private fun stateJson(
        login: Boolean? = null,
        referer: String? = null,
        callbackUrl: String? = null
    ): String {
        val state = mutableMapOf<String, Any>()
        if (login != null) {
            state["login"] = login
        }
        if (referer != null) {
            state["referer"] = referer
        }
        if (callbackUrl != null) {
            state["callbackUrl"] = callbackUrl
        }
        return objectMapper.writeValueAsString(state)
    }

    @TestConfiguration
    class KakaoApiTestConfig {
        @Bean
        @Primary
        fun testKakaoTokenApi(): KakaoTokenApi {
            return object : KakaoTokenApi {
                override fun getAccessToken(
                    grantType: String,
                    clientId: String,
                    redirectUri: String,
                    code: String
                ): KakaoTokenResponse {
                    return KakaoTokenResponse(
                        accessToken = "access-token",
                        tokenType = "bearer",
                        refreshToken = "refresh-token",
                        expiresIn = 3600,
                        refreshTokenExpiresIn = 7200
                    )
                }
            }
        }

        @Bean
        @Primary
        fun testKakaoUserInfoApi(): KakaoUserInfoApi {
            return object : KakaoUserInfoApi {
                override fun getUserInfo(accessToken: String): KakaoUserInfoResponse {
                    return KakaoUserInfoResponse(
                        id = TEST_KAKAO_ID,
                        connectedAt = "2025-01-01T00:00:00Z"
                    )
                }
            }
        }
    }

    companion object {
        private const val CALLBACK_URL = "https://client.example.com/callback"
        private const val TEST_KAKAO_ID = 123456789L
    }
}
