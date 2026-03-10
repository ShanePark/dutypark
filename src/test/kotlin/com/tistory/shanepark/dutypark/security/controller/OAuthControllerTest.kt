package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberConsentRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.SsoSignupRequest
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
import java.net.URI
import java.nio.charset.StandardCharsets
import java.util.Base64

@AutoConfigureMockMvc
@Import(OAuthControllerTest.KakaoApiTestConfig::class, OAuthControllerTest.NaverApiTestConfig::class)
class OAuthControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberSsoRegisterRepository: MemberSsoRegisterRepository

    @Autowired
    lateinit var memberConsentRepository: MemberConsentRepository

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Autowired
    lateinit var jwtConfig: JwtConfig

    @Test
    fun `kakao callback links kakao id when login requested`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.KAKAO)

        val stateJson = encodedState(login = true, referer = "/after")

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

        val linked = memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, TEST_KAKAO_ID.toString())
        assertThat(linked?.member?.id).isEqualTo(member.id)
    }

    @Test
    fun `kakao callback redirects to member page with already linked error when another member owns account`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.KAKAO)

        val existingMember = memberRepository.save(
            Member("other-user", "other@duty.park", "pass")
        )
        assertThat(existingMember.id).isNotEqualTo(member.id)
        linkSocialAccount(existingMember, SsoType.KAKAO, TEST_KAKAO_ID.toString())

        val referer = "http://localhost:5173/member"
        val stateJson = encodedState(login = true, referer = referer)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/kakao")
                .param("code", "test-code")
                .param("state", stateJson)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        )
            .andExpect(status().isFound)
            .andExpect(
                header().string(
                    HttpHeaders.LOCATION,
                    "$referer?socialLinkError=already_linked&socialProvider=kakao"
                )
            )
    }

    @Test
    fun `kakao callback redirects with login success when member exists`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.KAKAO)
        linkSocialAccount(member, SsoType.KAKAO, TEST_KAKAO_ID.toString())

        val redirect = "/todo?view=mine"
        val stateJson = encodedState(callbackUrl = CALLBACK_URL, referer = redirect)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/kakao")
                .param("code", "test-code")
                .param("state", stateJson)
        )
            .andExpect(status().isFound)
            .andExpect(
                header().string(
                    HttpHeaders.LOCATION,
                    "$CALLBACK_URL#login=success&redirect=%2Ftodo%3Fview%3Dmine"
                )
            )
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))

        assertThat(memberSsoRegisterRepository.findAll()).isEmpty()
    }

    @Test
    fun `kakao callback redirects with sso required when member not found`() {
        val redirect = "/todo?view=mine"
        val stateJson = encodedState(callbackUrl = CALLBACK_URL, referer = redirect)

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
        assertThat(location).isEqualTo(
            "$CALLBACK_URL#error=sso_required&uuid=${saved.uuid}&redirect=%2Ftodo%3Fview%3Dmine"
        )
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
    fun `naver callback links naver id when login requested`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.NAVER)

        val stateJson = encodedState(login = true, referer = "/after")

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/naver")
                .param("code", "test-code")
                .param("state", stateJson)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, "/after"))

        em.flush()
        em.clear()

        val linked = memberSocialAccountRepository.findByProviderAndSocialId(SsoType.NAVER, TEST_NAVER_ID)
        assertThat(linked?.member?.id).isEqualTo(member.id)
    }

    @Test
    fun `naver callback decodes utf8 encoded state`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.NAVER)
        val referer = "http://localhost:5173/member?tab=네이버"
        val stateJson = encodedState(login = true, referer = referer)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/naver")
                .param("code", "test-code")
                .param("state", stateJson)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        )
            .andExpect(status().isFound)
            .andExpect(header().string(HttpHeaders.LOCATION, URI.create(referer).toASCIIString()))

        em.flush()
        em.clear()

        val linked = memberSocialAccountRepository.findByProviderAndSocialId(SsoType.NAVER, TEST_NAVER_ID)
        assertThat(linked?.member?.id).isEqualTo(member.id)
    }

    @Test
    fun `naver callback redirects to member page with already linked error when another member owns account`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.NAVER)

        val existingMember = memberRepository.save(
            Member("other2", "other2@duty.park", "pass")
        )
        assertThat(existingMember.id).isNotEqualTo(member.id)
        linkSocialAccount(existingMember, SsoType.NAVER, TEST_NAVER_ID)

        val referer = "http://localhost:5173/member"
        val stateJson = encodedState(login = true, referer = referer)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/naver")
                .param("code", "test-code")
                .param("state", stateJson)
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
        )
            .andExpect(status().isFound)
            .andExpect(
                header().string(
                    HttpHeaders.LOCATION,
                    "$referer?socialLinkError=already_linked&socialProvider=naver"
                )
            )
    }

    @Test
    fun `naver callback redirects with login success when member exists`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        clearSocialAccount(member, SsoType.NAVER)
        linkSocialAccount(member, SsoType.NAVER, TEST_NAVER_ID)

        val redirect = "/todo?view=mine"
        val stateJson = encodedState(callbackUrl = CALLBACK_URL, referer = redirect)

        mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/naver")
                .param("code", "test-code")
                .param("state", stateJson)
        )
            .andExpect(status().isFound)
            .andExpect(
                header().string(
                    HttpHeaders.LOCATION,
                    "$CALLBACK_URL#login=success&redirect=%2Ftodo%3Fview%3Dmine"
                )
            )
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))

        assertThat(memberSsoRegisterRepository.findAll().none { it.ssoType == SsoType.NAVER }).isTrue()
    }

    @Test
    fun `naver callback redirects with sso required when member not found`() {
        val redirect = "/todo?view=mine"
        val stateJson = encodedState(callbackUrl = CALLBACK_URL, referer = redirect)

        val result = mockMvc.perform(
            MockMvcRequestBuilders.get("/api/auth/Oauth2ClientCallback/naver")
                .param("code", "test-code")
                .param("state", stateJson)
        )
            .andExpect(status().isFound)
            .andReturn()

        val saved = memberSsoRegisterRepository.findAll().single { it.ssoType == SsoType.NAVER }
        assertThat(saved.ssoType).isEqualTo(SsoType.NAVER)
        assertThat(saved.ssoId).isEqualTo(TEST_NAVER_ID)

        val location = result.response.getHeader(HttpHeaders.LOCATION)
        assertThat(location).isEqualTo(
            "$CALLBACK_URL#error=sso_required&uuid=${saved.uuid}&redirect=%2Ftodo%3Fview%3Dmine"
        )
    }

    @Test
    fun `sso signup creates member and consent with explicit versions`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.NAVER, "naver-id-1"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "new-user",
            termAgree = true,
            privacyAgree = true,
            termsVersion = "2025-01-15",
            privacyVersion = "2026-03-10"
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
        val linked = memberSocialAccountRepository.findByProviderAndSocialId(SsoType.NAVER, "naver-id-1")
        assertThat(linked?.member?.id).isEqualTo(created.id)

        val consents = memberConsentRepository.findAll().filter { it.member.id == created.id }
        assertThat(consents).hasSize(2)
        assertThat(consents.map { it.policyType }).containsExactlyInAnyOrder(PolicyType.TERMS, PolicyType.PRIVACY)

        assertThat(consents.single { it.policyType == PolicyType.TERMS }.consentVersion).isEqualTo("2025-01-15")
        assertThat(consents.single { it.policyType == PolicyType.PRIVACY }.consentVersion).isEqualTo("2026-03-10")
        consents.forEach { consent ->
            assertThat(consent.ipAddress).isEqualTo("127.0.0.1")
            assertThat(consent.userAgent).isEqualTo("Test-UA")
        }
    }

    @Test
    fun `sso signup returns bad request when policy terms version is missing`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-2"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "badtermv",
            termAgree = true,
            privacyAgree = true,
            privacyVersion = "2026-03-10"
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/sso/signup/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)

        assertThat(memberRepository.findAll().none { it.name == "badtermv" }).isTrue
        assertThat(memberConsentRepository.findAll().none { it.member.name == "badtermv" }).isTrue
    }

    @Test
    fun `sso signup returns bad request when policy privacy version is missing`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-3"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "badprivv",
            termAgree = true,
            privacyAgree = true,
            termsVersion = "2025-01-15"
        )
        val json = objectMapper.writeValueAsString(request)

        mockMvc.perform(
            MockMvcRequestBuilders.post("/api/auth/sso/signup/token")
                .contentType(MediaType.APPLICATION_JSON)
                .content(json)
        )
            .andExpect(status().isBadRequest)

        assertThat(memberRepository.findAll().none { it.name == "badprivv" }).isTrue
        assertThat(memberConsentRepository.findAll().none { it.member.name == "badprivv" }).isTrue
    }

    @Test
    fun `sso signup returns bad request when term not agreed`() {
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-2"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "bad-user-1",
            termAgree = false,
            privacyAgree = true,
            termsVersion = "2025-01-15",
            privacyVersion = "2026-03-10"
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
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao-id-4"))
        val request = SsoSignupRequest(
            uuid = ssoRegister.uuid,
            username = "bad-user-2",
            termAgree = true,
            privacyAgree = false,
            termsVersion = "2025-01-15",
            privacyVersion = "2026-03-10"
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

    private fun encodedState(
        login: Boolean? = null,
        referer: String? = null,
        callbackUrl: String? = null
    ): String {
        return Base64.getUrlEncoder()
            .withoutPadding()
            .encodeToString(
                stateJson(login = login, referer = referer, callbackUrl = callbackUrl)
                    .toByteArray(StandardCharsets.UTF_8)
            )
    }

    private fun clearSocialAccount(member: Member, provider: SsoType) {
        memberSocialAccountRepository.findByMemberAndProvider(member, provider)
            ?.let { memberSocialAccountRepository.delete(it) }
    }

    private fun linkSocialAccount(member: Member, provider: SsoType, socialId: String) {
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member = member, provider = provider, socialId = socialId)
        )
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

    @TestConfiguration
    class NaverApiTestConfig {
        @Bean
        @Primary
        fun testNaverTokenApi(): NaverTokenApi {
            return object : NaverTokenApi {
                override fun getAccessToken(
                    grantType: String,
                    clientId: String,
                    clientSecret: String,
                    code: String,
                    state: String
                ): NaverTokenResponse {
                    return NaverTokenResponse(
                        accessToken = "naver-access-token",
                        refreshToken = "naver-refresh-token",
                        tokenType = "bearer",
                        expiresIn = "3600"
                    )
                }
            }
        }

        @Bean
        @Primary
        fun testNaverUserInfoApi(): NaverUserInfoApi {
            return object : NaverUserInfoApi {
                override fun getUserInfo(accessToken: String): NaverUserInfoResponse {
                    return NaverUserInfoResponse(
                        resultCode = "00",
                        message = "success",
                        response = NaverUserInfoPayload(id = TEST_NAVER_ID)
                    )
                }
            }
        }
    }

    companion object {
        private const val CALLBACK_URL = "https://client.example.com/callback"
        private const val TEST_KAKAO_ID = 123456789L
        private const val TEST_NAVER_ID = "naver-user-123"
    }
}
