package com.tistory.shanepark.dutypark.common.config

import com.openai.client.OpenAIClientImpl
import com.openai.core.ClientOptions
import com.openai.core.RequestOptions
import com.openai.models.chat.completions.ChatCompletionCreateParams
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import okhttp3.Call
import org.springframework.ai.openai.http.okhttp.SpringAiOpenAiHttpClient
import org.springframework.ai.model.openai.autoconfigure.OpenAiChatProperties
import org.springframework.mock.env.MockEnvironment
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import okhttp3.Interceptor
import okhttp3.Protocol
import okhttp3.Request
import okhttp3.Response
import okio.Timeout
import java.time.Duration
import java.util.concurrent.TimeUnit
import java.util.concurrent.atomic.AtomicReference

class OpenAiTimeoutConfigTest {

    @Test
    fun `customizer applies configured timeouts to Spring AI OpenAI transport`() {
        val config = OpenAiTimeoutConfig(
            AiProperties(
                chat = AiProperties.ChatProperties(
                    connectTimeout = Duration.ofSeconds(7),
                    readTimeout = Duration.ofSeconds(11),
                )
            )
        )
        val builder = SpringAiOpenAiHttpClient.builder()

        config.openAiHttpClientBuilderCustomizer().customize(builder)

        val client = builder.build()
        try {
            val okHttpClient = client.getOkHttpClient()
            assertThat(okHttpClient.connectTimeoutMillis).isEqualTo(7_000)
            assertThat(okHttpClient.readTimeoutMillis).isEqualTo(11_000)
            assertThat(okHttpClient.writeTimeoutMillis).isEqualTo(11_000)
            assertThat(okHttpClient.callTimeoutMillis).isEqualTo(11_000)
        } finally {
            client.close()
        }
    }

    @Test
    fun `customizer preserves project header and non-default completions path`() {
        val config = OpenAiTimeoutConfig(
            aiProperties = AiProperties(),
            commonProjectId = "common-project",
            chatProjectId = "chat-project",
            completionsPath = "/custom/completions",
        )
        val builder = SpringAiOpenAiHttpClient.builder()
        config.openAiHttpClientBuilderCustomizer().customize(builder)

        val client = builder.build()
        try {
            val interceptor = client.getOkHttpClient().interceptors.last()
            val originalRequest = Request.Builder()
                .url("https://example.test/v1beta/openai/chat/completions")
                .build()
            val chain: Interceptor.Chain = mock()
            val call: Call = mock()
            val capturedRequest = AtomicReference<Request>()
            whenever(chain.request()).thenReturn(originalRequest)
            whenever(chain.withConnectTimeout(30_000, TimeUnit.MILLISECONDS)).thenReturn(chain)
            whenever(chain.withReadTimeout(120_000, TimeUnit.MILLISECONDS)).thenReturn(chain)
            whenever(chain.withWriteTimeout(120_000, TimeUnit.MILLISECONDS)).thenReturn(chain)
            whenever(chain.call()).thenReturn(call)
            whenever(call.timeout()).thenReturn(Timeout())
            whenever(chain.proceed(any<Request>())).thenAnswer { invocation ->
                val request = invocation.getArgument<Request>(0)
                capturedRequest.set(request)
                Response.Builder()
                    .request(request)
                    .protocol(Protocol.HTTP_1_1)
                    .code(200)
                    .message("OK")
                    .build()
            }

            interceptor.intercept(chain)

            assertThat(capturedRequest.get().header("OpenAI-Project")).isEqualTo("chat-project")
            assertThat(capturedRequest.get().url.encodedPath).isEqualTo("/custom/completions")
        } finally {
            client.close()
        }
    }

    @Test
    fun `official client preserves Gemini path headers and phase timeouts`() {
        val config = OpenAiTimeoutConfig(
            aiProperties = AiProperties(
                chat = AiProperties.ChatProperties(
                    connectTimeout = Duration.ofSeconds(7),
                    readTimeout = Duration.ofSeconds(11),
                )
            ),
            commonProjectId = "common-project",
            chatProjectId = " ",
            completionsPath = "/chat/completions",
        )
        val capturedRequest = AtomicReference<Request?>()
        val capturedConnectTimeout = AtomicReference<Int?>()
        val capturedReadTimeout = AtomicReference<Int?>()
        val capturedWriteTimeout = AtomicReference<Int?>()
        val capturedCallTimeout = AtomicReference<Long?>()
        val builder = SpringAiOpenAiHttpClient.builder()
        config.openAiHttpClientBuilderCustomizer().customize(builder)
        builder.interceptor(Interceptor { chain ->
            capturedRequest.set(chain.request())
            capturedConnectTimeout.set(chain.connectTimeoutMillis())
            capturedReadTimeout.set(chain.readTimeoutMillis())
            capturedWriteTimeout.set(chain.writeTimeoutMillis())
            capturedCallTimeout.set(chain.call().timeout().timeoutNanos())
            throw RequestCapturedException()
        })

        val httpClient = builder.build()
        val openAiClient = OpenAIClientImpl(
            ClientOptions.builder()
                .httpClient(httpClient)
                .baseUrl("https://generativelanguage.googleapis.com/v1beta/openai/")
                .apiKey("api-key")
                .organization("organization-id")
                .maxRetries(0)
                .build()
        )
        try {
            val request = ChatCompletionCreateParams.builder()
                .addUserMessage("hello")
                .model("gemma-4-31b-it")
                .build()
            try {
                openAiClient.chat().completions().create(
                    request,
                    RequestOptions.builder().timeout(Duration.ofSeconds(60)).build(),
                )
            } catch (_: Throwable) {
                // The interceptor intentionally aborts before a network request.
            }
        } finally {
            openAiClient.close()
        }

        val captured = capturedRequest.get()
        assertThat(captured).isNotNull
        assertThat(captured!!.url.toString())
            .isEqualTo("https://generativelanguage.googleapis.com/v1beta/openai/chat/completions")
        assertThat(captured.header("Authorization")).isEqualTo("Bearer api-key")
        assertThat(captured.header("OpenAI-Organization")).isEqualTo("organization-id")
        assertThat(captured.header("OpenAI-Project")).isEqualTo("common-project")
        assertThat(capturedConnectTimeout.get()).isEqualTo(7_000)
        assertThat(capturedReadTimeout.get()).isEqualTo(11_000)
        assertThat(capturedWriteTimeout.get()).isEqualTo(11_000)
        // RequestOptions.timeout is a total-call timeout and must remain overridable.
        assertThat(capturedCallTimeout.get()).isEqualTo(Duration.ofSeconds(60).toNanos())
    }

    @Test
    fun `blank chat api key falls back to common api key`() {
        val config = OpenAiTimeoutConfig(AiProperties())
        val properties = OpenAiChatProperties().apply { apiKey = " " }

        config.openAiChatPropertiesFallbackPostProcessor(
            MockEnvironment().withProperty("spring.ai.openai.api-key", "common-api-key")
        ).postProcessBeforeInitialization(properties, "openAiChatProperties")

        assertThat(properties.apiKey).isEqualTo("common-api-key")
    }

    private class RequestCapturedException : RuntimeException()
}
