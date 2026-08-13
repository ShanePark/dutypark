package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.TestUtils
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import java.net.http.HttpClient
import java.net.http.HttpRequest
import java.net.http.HttpResponse

class AppleProviderHttpClientTest {
    private val httpClient: HttpClient = mock()
    private val response: HttpResponse<String> = mock()
    private val client = AppleProviderHttpClient(TestUtils.jsr310JsonMapper(), httpClient)

    @Test
    fun `token endpoint 2xx malformed response is an invalid credential`() {
        whenever(response.statusCode()).thenReturn(200)
        whenever(response.body()).thenReturn("{malformed-json")
        whenever(
            httpClient.send(
                any<HttpRequest>(),
                any<HttpResponse.BodyHandler<String>>(),
            )
        ).thenReturn(response)

        val exception = assertThrows<AppleOAuthException> {
            client.exchange("authorization-code", "client-id", "client-secret")
        }

        assertThat(exception.message).isEqualTo("auth.apple.credential.invalid")
        assertThat(exception.errorCode).isEqualTo(401)
    }
}
