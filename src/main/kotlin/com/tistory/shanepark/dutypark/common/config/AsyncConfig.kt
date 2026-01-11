package com.tistory.shanepark.dutypark.common.config

import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.scheduling.annotation.EnableAsync
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor
import java.util.concurrent.Executor

@Configuration
@EnableAsync
class AsyncConfig {

    @Bean(name = ["thumbnailExecutor"])
    fun thumbnailExecutor(): Executor {
        val executor = ThreadPoolTaskExecutor()
        executor.setCorePoolSize(2)
        executor.setMaxPoolSize(5)
        executor.setQueueCapacity(100)
        executor.setThreadNamePrefix("thumbnail-")
        executor.setWaitForTasksToCompleteOnShutdown(true)
        executor.setAwaitTerminationSeconds(60)
        executor.initialize()
        return executor
    }

    @Bean(name = ["notificationExecutor"])
    fun notificationExecutor(): Executor {
        val executor = ThreadPoolTaskExecutor()
        executor.setCorePoolSize(2)
        executor.setMaxPoolSize(5)
        executor.setQueueCapacity(100)
        executor.setThreadNamePrefix("notification-")
        executor.setWaitForTasksToCompleteOnShutdown(true)
        executor.setAwaitTerminationSeconds(60)
        executor.initialize()
        return executor
    }
}
