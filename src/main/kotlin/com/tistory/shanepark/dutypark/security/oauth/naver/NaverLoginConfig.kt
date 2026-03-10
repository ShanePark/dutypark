package com.tistory.shanepark.dutypark.security.oauth.naver

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
class NaverLoginConfig {

    @Bean
    fun naverTokenApi(): NaverTokenApi {
        val httpClient: HttpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(10))
        val connector: ClientHttpConnector = ReactorClientHttpConnector(httpClient)

        val client = WebClient.builder()
            .baseUrl("https://nid.naver.com/oauth2.0")
            .clientConnector(connector)
            .build()

        return HttpServiceProxyFactory.builderFor(WebClientAdapter.create(client))
            .build()
            .createClient(NaverTokenApi::class.java)
    }

    @Bean
    fun naverUserInfoApi(): NaverUserInfoApi {
        val httpClient: HttpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(10))
        val connector: ClientHttpConnector = ReactorClientHttpConnector(httpClient)

        val client = WebClient.builder()
            .baseUrl("https://openapi.naver.com/v1")
            .clientConnector(connector)
            .build()

        return HttpServiceProxyFactory.builderFor(WebClientAdapter.create(client))
            .build()
            .createClient(NaverUserInfoApi::class.java)
    }
}
