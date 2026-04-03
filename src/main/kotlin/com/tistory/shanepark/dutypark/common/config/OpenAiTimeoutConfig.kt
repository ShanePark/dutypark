package com.tistory.shanepark.dutypark.common.config

import io.netty.channel.ChannelOption
import org.springframework.ai.model.SimpleApiKey
import org.springframework.ai.openai.api.OpenAiApi
import org.springframework.beans.factory.ObjectProvider
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpHeaders
import org.springframework.http.client.ReactorClientHttpRequestFactory
import org.springframework.http.client.reactive.ReactorClientHttpConnector
import org.springframework.web.client.ResponseErrorHandler
import org.springframework.web.client.RestClient
import org.springframework.web.reactive.function.client.WebClient
import reactor.netty.http.client.HttpClient
import org.springframework.util.Assert
import org.springframework.util.StringUtils

@Configuration
class OpenAiTimeoutConfig(
    private val aiProperties: AiProperties
) {
    @Bean
    fun openAiApi(
        restClientBuilderProvider: ObjectProvider<RestClient.Builder>,
        webClientBuilderProvider: ObjectProvider<WebClient.Builder>,
        responseErrorHandler: ResponseErrorHandler,
        @Value("\${spring.ai.openai.base-url:}") commonBaseUrl: String,
        @Value("\${spring.ai.openai.api-key:}") commonApiKey: String,
        @Value("\${spring.ai.openai.project-id:}") commonProjectId: String,
        @Value("\${spring.ai.openai.organization-id:}") commonOrganizationId: String,
        @Value("\${spring.ai.openai.chat.base-url:}") chatBaseUrl: String,
        @Value("\${spring.ai.openai.chat.api-key:}") chatApiKey: String,
        @Value("\${spring.ai.openai.chat.project-id:}") chatProjectId: String,
        @Value("\${spring.ai.openai.chat.organization-id:}") chatOrganizationId: String,
        @Value("\${spring.ai.openai.chat.completions-path:/v1/chat/completions}") completionsPath: String,
    ): OpenAiApi {
        val baseUrl = firstNonBlank(chatBaseUrl, commonBaseUrl)
        val apiKey = firstNonBlank(chatApiKey, commonApiKey)
        val projectId = firstNonBlank(chatProjectId, commonProjectId)
        val organizationId = firstNonBlank(chatOrganizationId, commonOrganizationId)
        val headers = HttpHeaders().apply {
            if (StringUtils.hasText(projectId)) {
                add("OpenAI-Project", projectId)
            }
            if (StringUtils.hasText(organizationId)) {
                add("OpenAI-Organization", organizationId)
            }
        }

        Assert.hasText(baseUrl, "OpenAI base URL must not be blank")
        Assert.hasText(apiKey, "OpenAI API key must not be blank")

        val connectTimeoutMillis = aiProperties.chat.connectTimeout.toMillis()
            .coerceIn(1, Int.MAX_VALUE.toLong())
            .toInt()
        val httpClient = HttpClient.create()
            .option(ChannelOption.CONNECT_TIMEOUT_MILLIS, connectTimeoutMillis)
            .responseTimeout(aiProperties.chat.readTimeout)
        val requestFactory = ReactorClientHttpRequestFactory(httpClient).apply {
            setConnectTimeout(aiProperties.chat.connectTimeout)
            setReadTimeout(aiProperties.chat.readTimeout)
        }
        val connector = ReactorClientHttpConnector(httpClient)

        return OpenAiApi.builder()
            .baseUrl(baseUrl)
            .apiKey(SimpleApiKey(apiKey))
            .headers(headers)
            .completionsPath(completionsPath)
            .restClientBuilder(
                restClientBuilderProvider.getIfAvailable(RestClient::builder)
                    .clone()
                    .requestFactory(requestFactory)
            )
            .webClientBuilder(
                webClientBuilderProvider.getIfAvailable(WebClient::builder)
                    .clone()
                    .clientConnector(connector)
            )
            .responseErrorHandler(responseErrorHandler)
            .build()
    }

    private fun firstNonBlank(primary: String, fallback: String): String {
        return if (StringUtils.hasText(primary)) primary else fallback
    }
}
