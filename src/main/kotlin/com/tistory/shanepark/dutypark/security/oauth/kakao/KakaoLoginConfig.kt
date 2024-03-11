package com.tistory.shanepark.dutypark.security.oauth.kakao

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.http.client.reactive.ClientHttpConnector
import org.springframework.http.client.reactive.ReactorClientHttpConnector
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.support.WebClientAdapter
import org.springframework.web.service.invoker.HttpServiceProxyFactory
import reactor.netty.http.client.HttpClient
import java.time.Duration

@Configuration
class KakaoLoginConfig {

    @Bean
    fun kakaoAuthApi(): KakaoTokenApi {
        val httpClient: HttpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(10))
        val connector: ClientHttpConnector = ReactorClientHttpConnector(httpClient)

        val client = WebClient.builder()
            .baseUrl("https://kauth.kakao.com/oauth")
            .clientConnector(connector)
            .build()

        return HttpServiceProxyFactory
            .builder(WebClientAdapter.forClient(client))
            .build()
            .createClient(KakaoTokenApi::class.java)
    }

    @Bean
    fun kakaoUserInfoApi(): KakaoUserInfoApi {
        val httpClient: HttpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(10))
        val connector: ClientHttpConnector = ReactorClientHttpConnector(httpClient)

        val client = WebClient.builder()
            .baseUrl("https://kapi.kakao.com/v2")
            .clientConnector(connector)
            .build()

        return HttpServiceProxyFactory
            .builder(WebClientAdapter.forClient(client))
            .build()
            .createClient(KakaoUserInfoApi::class.java)
    }

}
