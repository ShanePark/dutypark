package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoAccessTokenInfoApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoAccessTokenInfoResponse
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverRefreshTokenApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverTokenResponse
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoPayload
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoResponse
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.TestConfiguration
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Import
import org.springframework.context.annotation.Primary
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpStatus
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import org.springframework.web.client.HttpClientErrorException

@AutoConfigureMockMvc
@TestPropertySource(properties = ["oauth.kakao.app-id=123456789"])
@Import(MobileOAuthNativeControllerTest.ProviderApiTestConfig::class)
class MobileOAuthNativeControllerTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var memberSocialAccountRepository: MemberSocialAccountRepository

    @Test
    fun `Kakao native login verifies app binding and sets normal login cookies`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        memberSocialAccountRepository.saveAndFlush(
            MemberSocialAccount(member, SsoType.KAKAO, KAKAO_ID.toString())
        )

        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"KAKAO","accessToken":"native-kakao-token"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(false))
            .andExpect(jsonPath("$.expiresIn").isNumber)
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
    }

    @Test
    fun `Kakao native login rejects a token from another app`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"KAKAO","accessToken":"wrong-app-token"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.provider.failed"))
    }

    @Test
    fun `Kakao provider authentication failure is a bad request rather than a session unauthorized`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"KAKAO","accessToken":"provider-unauthorized-token"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.provider.failed"))
    }

    @Test
    fun `Naver native login exchanges refresh token before fetching profile`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"NAVER","refreshToken":"native-naver-refresh"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(true))
            .andExpect(jsonPath("$.signupUuid").isString)
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))

        assertThat(ProviderApiTestConfig.lastRefreshToken).isEqualTo("native-naver-refresh")
        assertThat(ProviderApiTestConfig.lastUserInfoAuthorization).isEqualTo("Bearer naver-native-access")
    }

    @Test
    fun `Naver native exchange does not accept a client supplied access token`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"NAVER","accessToken":"client-supplied-token"}""")
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.native.accessToken.unexpected"))
    }

    @Test
    fun `Naver provider rate limit is service unavailable rather than a session unauthorized`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"NAVER","refreshToken":"provider-rate-limited-refresh"}""")
        )
            .andExpect(status().isServiceUnavailable)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.provider.failed"))
    }

    @Test
    fun `native link requires an active authenticated member and does not rotate login cookies`() {
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val jwt = getJwt(member)

        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer $jwt")
                .contentType(MediaType.APPLICATION_JSON)
                .content("""{"provider":"KAKAO","purpose":"LINK","accessToken":"native-kakao-token"}""")
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(false))
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))

        em.flush()
        em.clear()
        assertThat(
            memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, KAKAO_ID.toString())
                ?.member?.id
        ).isEqualTo(member.id)
    }

    @Test
    fun `native account deletion purpose is rejected and capabilities expose configured providers`() {
        mockMvc.perform(
            post("/api/auth/mobile/oauth/native/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{"provider":"KAKAO","purpose":"DELETE_ACCOUNT","accessToken":"native-kakao-token"}"""
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.oauth.mobile.purpose.invalid"))

        mockMvc.perform(get("/api/auth/mobile/oauth/native/capabilities"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.providers[0]").value("KAKAO"))
            .andExpect(jsonPath("$.providers[1]").value("NAVER"))
    }

    @Test
    fun `native request string representation redacts provider credentials`() {
        val request = com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthNativeExchangeRequest(
            provider = "NAVER",
            refreshToken = "sensitive-refresh-token",
        )

        assertThat(request.toString())
            .doesNotContain("sensitive-refresh-token")
            .contains("[REDACTED]")
    }

    @TestConfiguration
    class ProviderApiTestConfig {
        @Bean
        @Primary
        fun nativeKakaoAccessTokenInfoApi(): KakaoAccessTokenInfoApi = object : KakaoAccessTokenInfoApi {
            override fun getAccessTokenInfo(accessToken: String): KakaoAccessTokenInfoResponse {
                if (accessToken == "Bearer provider-unauthorized-token") {
                    throw HttpClientErrorException(HttpStatus.UNAUTHORIZED)
                }
                return if (accessToken == "Bearer wrong-app-token") {
                    KakaoAccessTokenInfoResponse(
                        id = KAKAO_ID,
                        expiresIn = 3600,
                        appId = 987654321,
                    )
                } else {
                    KakaoAccessTokenInfoResponse(
                        id = KAKAO_ID,
                        expiresIn = 3600,
                        appId = 123456789,
                    )
                }
            }
        }

        @Bean
        @Primary
        fun nativeNaverRefreshTokenApi(): NaverRefreshTokenApi = object : NaverRefreshTokenApi {
            override fun refreshAccessToken(
                grantType: String,
                clientId: String,
                clientSecret: String,
                refreshToken: String,
            ): NaverTokenResponse {
                lastRefreshToken = refreshToken
                if (refreshToken == "provider-rate-limited-refresh") {
                    throw HttpClientErrorException(HttpStatus.TOO_MANY_REQUESTS)
                }
                return NaverTokenResponse(
                    accessToken = "naver-native-access",
                    refreshToken = null,
                    tokenType = "bearer",
                    expiresIn = "3600",
                )
            }
        }

        @Bean
        @Primary
        fun nativeNaverUserInfoApi(): NaverUserInfoApi = object : NaverUserInfoApi {
            override fun getUserInfo(accessToken: String): NaverUserInfoResponse {
                lastUserInfoAuthorization = accessToken
                return NaverUserInfoResponse(
                    resultCode = "00",
                    message = "success",
                    response = NaverUserInfoPayload(NAVER_ID),
                )
            }
        }

        companion object {
            var lastRefreshToken: String? = null
            var lastUserInfoAuthorization: String? = null
        }
    }

    companion object {
        private const val KAKAO_ID = 987654321L
        private const val NAVER_ID = "native-naver-id"
    }
}
