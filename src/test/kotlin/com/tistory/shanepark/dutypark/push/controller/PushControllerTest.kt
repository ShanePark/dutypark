package com.tistory.shanepark.dutypark.push.controller

import com.tistory.shanepark.dutypark.RestDocsTest
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import nl.martijndwars.webpush.PushService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.test.context.bean.override.mockito.MockitoBean
import org.springframework.http.MediaType
import org.springframework.restdocs.mockmvc.MockMvcRestDocumentation.document
import org.springframework.restdocs.payload.PayloadDocumentation.fieldWithPath
import org.springframework.restdocs.payload.PayloadDocumentation.requestFields
import org.springframework.restdocs.payload.PayloadDocumentation.responseFields
import org.springframework.test.context.TestPropertySource
import org.springframework.restdocs.mockmvc.RestDocumentationRequestBuilders
import org.springframework.test.web.servlet.result.MockMvcResultHandlers
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath
import org.springframework.test.web.servlet.result.MockMvcResultMatchers.status
import jakarta.servlet.http.Cookie

@TestPropertySource(
    properties = [
        "dutypark.webpush.vapid.public-key=test-public-key",
        "dutypark.webpush.vapid.private-key=test-private-key"
    ]
)
class PushControllerTest : RestDocsTest() {

    @Autowired
    lateinit var refreshTokenService: RefreshTokenService

    @Autowired
    lateinit var refreshTokenRepository: RefreshTokenRepository

    @MockitoBean
    lateinit var pushService: PushService

    @Test
    fun `get push enabled`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/auth/push/enabled")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.enabled").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "push/enabled",
                    responseFields(
                        fieldWithPath("enabled").description("Whether web push is enabled")
                    )
                )
            )
    }

    @Test
    fun `get vapid public key`() {
        mockMvc.perform(
            RestDocumentationRequestBuilders.get("/api/auth/push/vapid-public-key")
                .accept(MediaType.APPLICATION_JSON)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.publicKey").value("test-public-key"))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "push/vapid-public-key",
                    responseFields(
                        fieldWithPath("publicKey").description("VAPID public key")
                    )
                )
            )
    }

    @Test
    fun `subscribe push`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )

        val requestBody = """
            {
              "endpoint": "https://example.com/endpoint",
              "keys": {
                "p256dh": "test-p256dh",
                "auth": "test-auth"
              }
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/push/subscribe")
                .withAuth(TestData.member)
                .cookie(Cookie("refresh_token", refreshToken.token))
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody)
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "push/subscribe",
                    requestFields(
                        fieldWithPath("endpoint").description("Push endpoint URL"),
                        fieldWithPath("keys").description("Subscription keys"),
                        fieldWithPath("keys.p256dh").description("P-256 ECDH key (Base64)"),
                        fieldWithPath("keys.auth").description("Auth secret (Base64)")
                    ),
                    responseFields(
                        fieldWithPath("success").description("Whether subscription was saved")
                    )
                )
            )

        val updatedToken = refreshTokenRepository.findByToken(refreshToken.token)
        assertThat(updatedToken?.pushEndpoint).isEqualTo("https://example.com/endpoint")
    }

    @Test
    fun `unsubscribe push`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )
        refreshToken.subscribePush(
            endpoint = "https://example.com/unsubscribe",
            p256dh = "unsubscribe-p256dh",
            auth = "unsubscribe-auth"
        )
        refreshTokenRepository.save(refreshToken)

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/push/unsubscribe")
                .withAuth(TestData.member)
                .cookie(Cookie("refresh_token", refreshToken.token))
        )
            .andExpect(status().isOk)
            .andExpect(jsonPath("$.success").value(true))
            .andDo(MockMvcResultHandlers.print())
            .andDo(
                document(
                    "push/unsubscribe",
                    responseFields(
                        fieldWithPath("success").description("Whether subscription was removed")
                    )
                )
            )

        val updatedToken = refreshTokenRepository.findByToken(refreshToken.token)
        assertThat(updatedToken?.pushEndpoint).isNull()
    }

    @Test
    fun `subscribe returns 401 when refresh token is missing`() {
        val requestBody = """
            {
              "endpoint": "https://example.com/endpoint",
              "keys": {
                "p256dh": "test-p256dh",
                "auth": "test-auth"
              }
            }
        """.trimIndent()

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/push/subscribe")
                .withAuth(TestData.member)
                .contentType(MediaType.APPLICATION_JSON)
                .content(requestBody)
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.success").value(false))
    }

    @Test
    fun `unsubscribe returns 401 when refresh token belongs to another member`() {
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = TestData.member2.id!!,
            remoteAddr = "127.0.0.1",
            userAgent = "test-agent"
        )

        mockMvc.perform(
            RestDocumentationRequestBuilders.post("/api/auth/push/unsubscribe")
                .withAuth(TestData.member)
                .cookie(Cookie("refresh_token", refreshToken.token))
        )
            .andExpect(status().isUnauthorized)
            .andExpect(jsonPath("$.success").value(false))
    }
}
