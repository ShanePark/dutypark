package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.apple.AppleNativeOAuthService
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResult
import org.junit.jupiter.api.Test
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.assertj.core.api.Assertions.assertThat
import org.mockito.kotlin.any
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.eq
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.MediaType
import org.springframework.http.HttpHeaders
import org.springframework.test.context.TestPropertySource
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.cookie
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@AutoConfigureMockMvc
@TestPropertySource(
    properties = [
        "oauth.apple.web-client-id=io.github.shanepark.dutypark.web",
        "oauth.apple.web-redirect-uri=https://dutypark.com/auth/apple/callback",
    ]
)
class WebAppleOAuthControllerTest : DutyparkIntegrationTest() {
    @Autowired lateinit var mockMvc: MockMvc
    @MockitoBean lateinit var appleNativeOAuthService: AppleNativeOAuthService

    @Test
    fun `web Apple exchange accepts raw nonce and sets normal login cookies`() {
        whenever(
            appleNativeOAuthService.exchangeForClient(
                any(),
                anyOrNull(),
                any(),
                eq("io.github.shanepark.dutypark.web"),
                eq("https://dutypark.com/auth/apple/callback"),
            )
        ).thenReturn(
            MobileOAuthExchangeResult(
                MobileOAuthExchangeResponse(signupRequired = false, expiresIn = 1800),
                accessToken = "apple-access",
                refreshToken = "apple-refresh",
            )
        )

        mockMvc.perform(
            post("/api/auth/web/oauth/apple/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{
                        "identityToken":"identity-token",
                        "authorizationCode":"authorization-code",
                        "rawNonce":"${"n".repeat(32)}",
                        "purpose":"LOGIN"
                    }""".trimIndent()
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(false))
            .andExpect(jsonPath("$.expiresIn").value(1800))
            .andExpect(cookie().exists("access_token"))
            .andExpect(cookie().exists("refresh_token"))
    }

    @Test
    fun `web Apple link delegates authenticated member without replacing login cookies`() {
        whenever(
            appleNativeOAuthService.exchangeForClient(
                any(),
                any(),
                any(),
                eq("io.github.shanepark.dutypark.web"),
                eq("https://dutypark.com/auth/apple/callback"),
            )
        ).thenReturn(
            MobileOAuthExchangeResult(MobileOAuthExchangeResponse(signupRequired = false))
        )
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()

        mockMvc.perform(
            post("/api/auth/web/oauth/apple/exchange")
                .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{
                        "identityToken":"identity-token",
                        "authorizationCode":"authorization-code",
                        "rawNonce":"${"n".repeat(32)}",
                        "purpose":"LINK"
                    }""".trimIndent()
                )
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.signupRequired").value(false))
            .andExpect(cookie().doesNotExist("access_token"))
            .andExpect(cookie().doesNotExist("refresh_token"))

        val loginMember = argumentCaptor<LoginMember>()
        verify(appleNativeOAuthService).exchangeForClient(
            any(),
            loginMember.capture(),
            any(),
            eq("io.github.shanepark.dutypark.web"),
            eq("https://dutypark.com/auth/apple/callback"),
        )
        assertThat(loginMember.firstValue.id).isEqualTo(member.id)
    }

    @Test
    fun `web Apple exchange rejects a short raw nonce`() {
        mockMvc.perform(
            post("/api/auth/web/oauth/apple/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{
                        "identityToken":"identity-token",
                        "authorizationCode":"authorization-code",
                        "rawNonce":"short",
                        "purpose":"LOGIN"
                    }""".trimIndent()
                )
        ).andExpect(status().isBadRequest)
    }

    @ParameterizedTest
    @ValueSource(strings = ["DELETE_ACCOUNT"])
    fun `web Apple exchange rejects non-login purposes`(purpose: String) {
        mockMvc.perform(
            post("/api/auth/web/oauth/apple/exchange")
                .contentType(MediaType.APPLICATION_JSON)
                .content(
                    """{
                        "identityToken":"identity-token",
                        "authorizationCode":"authorization-code",
                        "rawNonce":"${"n".repeat(32)}",
                        "purpose":"$purpose"
                    }""".trimIndent()
                )
        )
            .andExpect(status().isBadRequest)
            .andExpect(jsonPath("$.code").value("auth.apple.purpose.invalid"))
    }
}
