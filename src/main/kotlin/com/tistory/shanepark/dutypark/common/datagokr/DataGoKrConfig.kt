package com.tistory.shanepark.dutypark.common.datagokr

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
class DataGoKrConfig {

    @Bean
    fun dataGoApi(): DataGoKrApi {
        // It usually responds in 50ms, but Sometimes it takes more than 5 seconds.
        val httpClient: HttpClient = HttpClient.create()
            .responseTimeout(Duration.ofSeconds(10))
        val connector: ClientHttpConnector = ReactorClientHttpConnector(httpClient)

        val client = WebClient.builder()
            .baseUrl("https://apis.data.go.kr")
            .clientConnector(connector)
            .build()

        return HttpServiceProxyFactory
            .builderFor(WebClientAdapter.create(client))
            .build()
            .createClient(DataGoKrApi::class.java)
    }

}
