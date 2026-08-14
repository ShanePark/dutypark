package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.TestUtils
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
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

    @Test
    fun `web token exchange sends the server selected redirect uri`() {
        whenever(response.statusCode()).thenReturn(200)
        whenever(response.body()).thenReturn("""{"refresh_token":"refresh","id_token":"identity"}""")
        whenever(httpClient.send(any<HttpRequest>(), any<HttpResponse.BodyHandler<String>>())).thenReturn(response)

        client.exchange(
            "authorization-code",
            "io.github.shanepark.dutypark.web",
            "client-secret",
            "https://dutypark.com/auth/apple/callback",
        )

        val request = argumentCaptor<HttpRequest>()
        verify(httpClient).send(request.capture(), any<HttpResponse.BodyHandler<String>>())
        val publisher = request.firstValue.bodyPublisher().orElseThrow()
        val subscriber = BodySubscriber()
        publisher.subscribe(subscriber)
        assertThat(subscriber.body()).contains(
            "client_id=io.github.shanepark.dutypark.web",
            "redirect_uri=https%3A%2F%2Fdutypark.com%2Fauth%2Fapple%2Fcallback",
        )
    }

    private class BodySubscriber : java.util.concurrent.Flow.Subscriber<java.nio.ByteBuffer> {
        private val bytes = java.io.ByteArrayOutputStream()
        override fun onSubscribe(subscription: java.util.concurrent.Flow.Subscription) = subscription.request(Long.MAX_VALUE)
        override fun onNext(item: java.nio.ByteBuffer) {
            val chunk = ByteArray(item.remaining())
            item.get(chunk)
            bytes.write(chunk)
        }
        override fun onError(throwable: Throwable) = throw throwable
        override fun onComplete() = Unit
        fun body(): String = bytes.toString(Charsets.UTF_8)
    }
}
