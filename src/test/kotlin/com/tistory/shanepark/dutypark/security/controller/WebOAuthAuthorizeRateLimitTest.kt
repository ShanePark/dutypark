package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.security.oauth.web.WebOAuthTransactionRepository
import com.tistory.shanepark.dutypark.security.repository.LoginAttemptRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc
import org.springframework.http.HttpHeaders
import org.springframework.http.MediaType
import org.springframework.test.context.TestPropertySource
import org.springframework.test.web.servlet.MockMvc
import org.springframework.test.web.servlet.MvcResult
import org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status

@AutoConfigureMockMvc
@TestPropertySource(properties = [
    "dutypark.oauth.authorize-rate-limit.max-attempts=2",
    "dutypark.oauth.authorize-rate-limit.global-max-attempts=3",
    "dutypark.oauth.authorize-rate-limit.window-minutes=15",
])
class WebOAuthAuthorizeRateLimitTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var mockMvc: MockMvc

    @Autowired
    lateinit var transactionRepository: WebOAuthTransactionRepository

    @Autowired
    lateinit var loginAttemptRepository: LoginAttemptRepository

    @Test
    fun `anonymous provider switching is blocked before session and oauth transaction creation`() {
        authorize("KAKAO", SOURCE_IP)
            .also { assertThat(it.request.getSession(false)).isNotNull() }
        authorize("NAVER", SOURCE_IP)
            .also { assertThat(it.request.getSession(false)).isNotNull() }
        assertThat(transactionRepository.count()).isEqualTo(2)

        listOf("KAKAO", "NAVER").forEach { provider ->
            val blocked = mockMvc.perform(
                post("/api/auth/oauth2/authorize")
                    .with { it.remoteAddr = SOURCE_IP; it }
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"provider":"$provider","purpose":"LOGIN","referer":"/"}""")
            )
                .andExpect(status().isTooManyRequests)
                .andExpect(jsonPath("$.code").value("common.rateLimit.exceeded"))
                .andReturn()

            assertThat(blocked.request.getSession(false)).isNull()
            assertThat(transactionRepository.count()).isEqualTo(2)
        }

        authorize("NAVER", "198.51.100.24")
            .also { assertThat(it.request.getSession(false)).isNotNull() }
        assertThat(transactionRepository.count()).isEqualTo(3)
        assertThat(loginAttemptRepository.count()).isEqualTo(6)

        listOf("KAKAO", "NAVER").forEachIndexed { index, provider ->
            val blocked = mockMvc.perform(
                post("/api/auth/oauth2/authorize")
                    .with { it.remoteAddr = "203.0.113.${index + 10}"; it }
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"provider":"$provider","purpose":"LOGIN","referer":"/"}""")
            )
                .andExpect(status().isTooManyRequests)
                .andReturn()

            assertThat(blocked.request.getSession(false)).isNull()
            assertThat(transactionRepository.count()).isEqualTo(3)
            assertThat(loginAttemptRepository.count()).isEqualTo(6)
        }

        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        listOf("LOGIN", "LINK").forEachIndexed { index, purpose ->
            val blocked = mockMvc.perform(
                post("/api/auth/oauth2/authorize")
                    .with { it.remoteAddr = "192.0.2.${index + 10}"; it }
                    .header(HttpHeaders.AUTHORIZATION, "Bearer ${getJwt(member)}")
                    .contentType(MediaType.APPLICATION_JSON)
                    .content("""{"provider":"KAKAO","purpose":"$purpose","referer":"/member"}""")
            )
                .andExpect(status().isTooManyRequests)
                .andReturn()

            assertThat(blocked.request.getSession(false)).isNull()
            assertThat(transactionRepository.count()).isEqualTo(3)
            assertThat(loginAttemptRepository.count()).isEqualTo(6)
        }
    }

    private fun authorize(provider: String, ipAddress: String): MvcResult = mockMvc.perform(
        post("/api/auth/oauth2/authorize")
            .with { it.remoteAddr = ipAddress; it }
            .contentType(MediaType.APPLICATION_JSON)
            .content("""{"provider":"$provider","purpose":"LOGIN","referer":"/"}""")
    )
        .andExpect(status().isOk)
        .andReturn()

    companion object {
        private const val SOURCE_IP = "198.51.100.23"
    }
}
