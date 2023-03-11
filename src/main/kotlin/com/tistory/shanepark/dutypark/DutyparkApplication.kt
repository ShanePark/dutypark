package com.tistory.shanepark.dutypark

import com.tistory.shanepark.dutypark.security.config.AdminAuthInterceptor
import com.tistory.shanepark.dutypark.security.config.JwtAuthInterceptor
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.autoconfigure.SpringBootApplication
import org.springframework.boot.autoconfigure.security.servlet.UserDetailsServiceAutoConfiguration
import org.springframework.boot.runApplication
import org.springframework.context.annotation.Bean
import org.springframework.core.task.TaskExecutor
import org.springframework.data.jpa.repository.config.EnableJpaAuditing
import org.springframework.scheduling.annotation.EnableScheduling
import org.springframework.scheduling.concurrent.ThreadPoolTaskExecutor
import org.springframework.web.servlet.config.annotation.InterceptorRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer

@SpringBootApplication(exclude = [UserDetailsServiceAutoConfiguration::class])
@EnableJpaAuditing
@EnableScheduling
class DutyparkApplication(
    private val authService: AuthService,
    private val jwtConfig: JwtConfig,
    @Value("\${server.ssl.enabled}") private val isSecure: Boolean
) : WebMvcConfigurer {
    override fun addInterceptors(
        registry: InterceptorRegistry
    ) {
        registry.addInterceptor(JwtAuthInterceptor(authService, jwtConfig.tokenValidityInSeconds, isSecure))
            .addPathPatterns("/**")
            .excludePathPatterns("/**/*.css", "/**/*.js", "/**/*.map", "/error")
            .order(0)
        registry.addInterceptor(AdminAuthInterceptor())
            .addPathPatterns("/admin/**")
            .order(1)
    }
}

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
