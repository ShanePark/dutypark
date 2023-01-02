package com.tistory.shanepark.dutypark.common.config

import com.tistory.shanepark.dutypark.security.interceptor.AuthInterceptor
import com.tistory.shanepark.dutypark.security.service.AuthService
import org.springframework.context.annotation.Configuration
import org.springframework.web.servlet.config.annotation.InterceptorRegistry
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer

@Configuration
class WebMvcConfigure(
    val authService: AuthService
) : WebMvcConfigurer {

    override fun addInterceptors(registry: InterceptorRegistry) {
        registry.addInterceptor(AuthInterceptor(authService))
            .addPathPatterns("/**")
    }
}