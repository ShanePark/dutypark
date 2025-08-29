package com.tistory.shanepark.dutypark

import com.fasterxml.jackson.databind.ObjectMapper
import com.fasterxml.jackson.datatype.jsr310.JavaTimeModule
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication
import org.springframework.cache.annotation.EnableCaching
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.PropertySource
import org.springframework.data.jpa.repository.config.EnableJpaAuditing
import org.springframework.scheduling.annotation.EnableScheduling

@SpringBootApplication(exclude = [UserDetailsServiceAutoConfiguration::class])
@EnableJpaAuditing
@EnableScheduling
@EnableCaching
@ConfigurationPropertiesScan
@PropertySource("classpath:git.properties", ignoreResourceNotFound = true)
class DutyparkApplication

fun main(args: Array<String>) {
    runApplication<DutyparkApplication>(*args)
}

@Bean
fun objectMapper(): ObjectMapper {
    return ObjectMapper().apply {
        registerModule(JavaTimeModule())
    }
}




