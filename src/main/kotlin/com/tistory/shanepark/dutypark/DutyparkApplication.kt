package com.tistory.shanepark.dutypark

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration
import org.springframework.boot.context.properties.ConfigurationPropertiesScan
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.core.task.TaskExecutor
import org.springframework.data.jpa.repository.config.EnableJpaAuditing
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor

@SpringBootApplication(exclude = [UserDetailsServiceAutoConfiguration::class])
@EnableJpaAuditing
@EnableScheduling
@ConfigurationPropertiesScan
class DutyparkApplication

fun main(args: Array<String>) {
    runApplication<DutyparkApplication>(*args)
}

@Bean
fun threadPoolTaskExecutor(): TaskExecutor {
    val executor = ThreadPoolTaskExecutor()
    executor.corePoolSize = 5
    executor.maxPoolSize = 5
    executor.initialize()
    return executor
}
