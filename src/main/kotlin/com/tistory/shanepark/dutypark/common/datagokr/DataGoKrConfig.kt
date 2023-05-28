package com.tistory.shanepark.dutypark.common.datagokr

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.web.reactive.function.client.WebClient
import org.springframework.web.reactive.function.client.support.WebClientAdapter
import org.springframework.web.service.invoker.HttpServiceProxyFactory

@Configuration
class DataGoKrConfig {

    @Bean
    fun dataGoApi(): DataGoKrApi {
        val client = WebClient.create("https://apis.data.go.kr")

        return HttpServiceProxyFactory
            .builder(WebClientAdapter.forClient(client))
            .build()
            .createClient(DataGoKrApi::class.java)
    }

}
