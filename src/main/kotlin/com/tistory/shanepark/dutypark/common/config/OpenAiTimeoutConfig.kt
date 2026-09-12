package com.tistory.shanepark.dutypark.common.config

import com.openai.core.Timeout
import okhttp3.Interceptor
import org.springframework.ai.openai.http.okhttp.OpenAiHttpClientBuilderCustomizer
import org.springframework.ai.model.openai.autoconfigure.OpenAiChatProperties
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.beans.factory.config.BeanPostProcessor
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.beans.factory.annotation.Value
import org.springframework.core.env.Environment
import org.springframework.util.StringUtils
import java.util.concurrent.TimeUnit

@Configuration
class OpenAiTimeoutConfig @Autowired constructor(
    private val aiProperties: AiProperties,
    @Value("\${spring.ai.openai.project-id:}") private val commonProjectId: String = "",
    @Value("\${spring.ai.openai.chat.project-id:}") private val chatProjectId: String = "",
    @Value("\${spring.ai.openai.chat.completions-path:/v1/chat/completions}")
    private val completionsPath: String = DEFAULT_COMPLETIONS_PATH,
) {
    /**
     * Spring AI 2 uses the official OpenAI Java client, so customize its OkHttp
     * transport instead of providing the removed OpenAiApi bean.
     */
    @Bean
    fun openAiHttpClientBuilderCustomizer(): OpenAiHttpClientBuilderCustomizer =
        OpenAiHttpClientBuilderCustomizer { builder ->
            builder.timeout(
                Timeout.builder()
                    .connect(aiProperties.chat.connectTimeout)
                    .read(aiProperties.chat.readTimeout)
                    .write(aiProperties.chat.readTimeout)
                    .request(aiProperties.chat.readTimeout)
                    .build()
            )
            builder.interceptor(compatibilityInterceptor())
        }

    /**
     * Spring AI's common-property resolver treats a null chat key as absent but keeps an
     * explicitly bound blank key. Normalize that edge case before auto-configuration resolves
     * the common/chat connection so environment-provided blank overrides keep the old fallback.
     */
    @Bean
    fun openAiChatPropertiesFallbackPostProcessor(environment: Environment): BeanPostProcessor =
        object : BeanPostProcessor {
            override fun postProcessBeforeInitialization(bean: Any, beanName: String): Any {
                if (bean is OpenAiChatProperties && !StringUtils.hasText(bean.apiKey)) {
                    val commonApiKey = environment.getProperty("spring.ai.openai.api-key")
                    if (StringUtils.hasText(commonApiKey)) {
                        bean.apiKey = commonApiKey
                    }
                }
                return bean
            }
        }

    private fun compatibilityInterceptor(): Interceptor {
        val projectId = firstNonBlank(chatProjectId, commonProjectId)
        val normalizedCompletionsPath = completionsPath
            .takeIf(StringUtils::hasText)
            ?.let(::normalizePath)
            ?: DEFAULT_COMPLETIONS_PATH
        val connectTimeoutMillis = aiProperties.chat.connectTimeout.toTimeoutMillis()
        val readTimeoutMillis = aiProperties.chat.readTimeout.toTimeoutMillis()

        return Interceptor { chain ->
            val request = chain.request()
            val requestBuilder = request.newBuilder()
            if (StringUtils.hasText(projectId)) {
                requestBuilder.header(PROJECT_HEADER, projectId)
            }
            if (normalizedCompletionsPath !in DEFAULT_COMPLETIONS_PATHS &&
                request.url.encodedPath.endsWith(CHAT_COMPLETIONS_SUFFIX)
            ) {
                val rewrittenUrl = request.url.newBuilder()
                    .encodedPath(normalizedCompletionsPath)
                    .build()
                requestBuilder.url(rewrittenUrl)
            }

            // Spring AI passes RequestOptions.timeout to the SDK for every request. That
            // value is applied to all OkHttp phase timeout categories and would otherwise
            // replace the separate connect/read settings configured above. Restore the phase
            // settings at the actual call boundary; leave call timeout untouched so an
            // explicit per-request timeout still has its documented meaning.
            val timeoutChain = chain
                .withConnectTimeout(connectTimeoutMillis, TimeUnit.MILLISECONDS)
                .withReadTimeout(readTimeoutMillis, TimeUnit.MILLISECONDS)
                .withWriteTimeout(readTimeoutMillis, TimeUnit.MILLISECONDS)
            timeoutChain.proceed(requestBuilder.build())
        }
    }

    private fun java.time.Duration.toTimeoutMillis(): Int =
        toMillis().coerceIn(1L, Int.MAX_VALUE.toLong()).toInt()

    private fun firstNonBlank(primary: String, fallback: String): String =
        if (StringUtils.hasText(primary)) primary else fallback

    private fun normalizePath(path: String): String =
        if (path.startsWith('/')) path else "/$path"

    private companion object {
        const val DEFAULT_COMPLETIONS_PATH = "/v1/chat/completions"
        const val CHAT_COMPLETIONS_SUFFIX = "/chat/completions"
        val DEFAULT_COMPLETIONS_PATHS = setOf(DEFAULT_COMPLETIONS_PATH, "/chat/completions")
        const val PROJECT_HEADER = "OpenAI-Project"
    }
}
