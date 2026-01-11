package com.tistory.shanepark.dutypark

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication
import org.springframework.boot.security.autoconfigure.UserDetailsServiceAutoConfiguration
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.PropertySource
import org.springframework.data.jpa.repository.config.EnableJpaAuditing
import org.springframework.scheduling.annotation.EnableScheduling
import tools.jackson.databind.json.JsonMapper

@SpringBootApplication(exclude = [UserDetailsServiceAutoConfiguration::class])
@EnableJpaAuditing
@EnableScheduling
@ConfigurationPropertiesScan
@PropertySource("classpath:git.properties", ignoreResourceNotFound = true)
class DutyparkApplication

fun main(args: Array<String>) {
    runApplication<DutyparkApplication>(*args)
}

@Bean
fun jsonMapper(): JsonMapper {
    return JsonMapper.builder().build()
}




