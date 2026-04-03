package com.tistory.shanepark.dutypark.common.config

import io.netty.channel.ChannelOption
import org.springframework.ai.model.SimpleApiKey
import org.springframework.ai.model.openai.autoconfigure.OpenAIAutoConfigurationUtil
import org.springframework.ai.model.openai.autoconfigure.OpenAiChatProperties
import org.springframework.ai.model.openai.autoconfigure.OpenAiConnectionProperties
import org.springframework.ai.openai.api.OpenAiApi
import org.springframework.beans.factory.ObjectProvider
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.client.ReactorClientHttpRequestFactory
import org.springframework.http.client.reactive.ReactorClientHttpConnector
import org.springframework.web.client.ResponseErrorHandler
import org.springframework.web.client.RestClient
import org.springframework.web.reactive.function.client.WebClient
import reactor.netty.http.client.HttpClient

@Configuration
class OpenAiTimeoutConfig(
    private val aiProperties: AiProperties
) {
    @Bean
    fun openAiApi(
        commonProperties: OpenAiConnectionProperties,
        chatProperties: OpenAiChatProperties,
        restClientBuilderProvider: ObjectProvider<RestClient.Builder>,
        webClientBuilderProvider: ObjectProvider<WebClient.Builder>,
        responseErrorHandler: ResponseErrorHandler,
    ): OpenAiApi {
        val resolved = OpenAIAutoConfigurationUtil.resolveConnectionProperties(commonProperties, chatProperties, "chat")

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
            .baseUrl(resolved.baseUrl())
            .apiKey(SimpleApiKey(resolved.apiKey()))
            .headers(resolved.headers())
            .completionsPath(chatProperties.completionsPath)
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
}
