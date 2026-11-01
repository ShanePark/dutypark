package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.ValueSource
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.*
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.*

@AutoConfigureMockMvc
@TestPropertySource(properties = ["oauth.apple.client-id=test-native-client", "oauth.apple.web-client-id=test-web-client", "oauth.apple.web-redirect-uri=https://example.com/callback"])
class OAuthPolicySessionPreservationTest : DutyparkIntegrationTest() {
    @Autowired lateinit var mockMvc: MockMvc

    @ParameterizedTest
    @ValueSource(strings = ["web-link", "mobile-link", "native-link", "apple-native-link", "apple-web-link", "password-reauth", "mobile-delete-reauth"])
    fun `forbidden authentication settings preserve the impersonation session`(scenario: String) {
        val jwt = getImpersonationJwt(TestData.member, TestData.admin)
        val (path, body) = when (scenario) {
            "web-link" -> "/api/auth/oauth2/authorize" to """{"provider":"KAKAO","purpose":"LINK","referer":"/member"}"""
            "mobile-link", "mobile-delete-reauth" -> "/api/auth/mobile/oauth/authorize" to
                """{"provider":"KAKAO","purpose":"${if (scenario == "mobile-link") "LINK" else "DELETE_ACCOUNT"}","callbackUri":"dutypark://oauth/callback","codeChallenge":"${"c".repeat(43)}"}"""
            "native-link" -> "/api/auth/mobile/oauth/native/exchange" to """{"provider":"KAKAO","purpose":"LINK","accessToken":"test-token"}"""
            "apple-native-link" -> "/api/auth/mobile/oauth/apple/exchange" to """{"purpose":"LINK","identityToken":"test-identity","authorizationCode":"test-code","nonce":"${"n".repeat(32)}"}"""
            "apple-web-link" -> "/api/auth/web/oauth/apple/exchange" to """{"purpose":"LINK","identityToken":"test-identity","authorizationCode":"test-code","rawNonce":"${"n".repeat(32)}"}"""
            "password-reauth" -> "/api/auth/reauth/password" to """{"password":"wrong-password","purpose":"DELETE_ACCOUNT"}"""
            else -> error("Unknown scenario")
        }
        mockMvc.perform(post(path).header(HttpHeaders.AUTHORIZATION, "Bearer $jwt").contentType(MediaType.APPLICATION_JSON).content(body))
            .andExpect(status().isForbidden)
            .andExpect(jsonPath("$.code").value("auth.reauth.impersonationForbidden"))
        mockMvc.perform(get("/api/auth/status").header(HttpHeaders.AUTHORIZATION, "Bearer $jwt"))
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.id").value(TestData.member.id))
            .andExpect(jsonPath("$.isImpersonating").value(true))
    }
}
