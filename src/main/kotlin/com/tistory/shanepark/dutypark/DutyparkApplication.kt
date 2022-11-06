package com.tistory.shanepark.dutypark

import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.core.task.TaskExecutor
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor

@SpringBootApplication
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
