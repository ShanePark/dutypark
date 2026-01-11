package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.filters.AdminAuthFilter
import com.tistory.shanepark.dutypark.security.filters.JwtAuthFilter
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.Filter
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.servlet.FilterRegistrationBean
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.core.Ordered
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.access.intercept.AuthorizationFilter
import org.springframework.web.cors.CorsConfiguration
import org.springframework.web.cors.CorsConfigurationSource
import org.springframework.web.cors.UrlBasedCorsConfigurationSource
import org.springframework.web.filter.ForwardedHeaderFilter

@Configuration
class SecurityConfig(
    private val authService: AuthService,
    private val cookieService: CookieService,
    @param:Value("\${dutypark.cors.allowed-origins:}") private val corsAllowedOrigins: String
) {

    private val log = logger()

    init {
        log.info("Init SecurityConfig. corsAllowedOrigins: $corsAllowedOrigins")
    }

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        val jwtAuthFilter = JwtAuthFilter(authService, cookieService)
        http.addFilterBefore(jwtAuthFilter, AuthorizationFilter::class.java)

        return http
            .authorizeHttpRequests { it.anyRequest().permitAll() }
            .logout { it.disable() }
            .csrf { it.disable() }
            .cors { it.configurationSource(corsConfigurationSource()) }
            .build()
    }

    @Bean
    fun corsConfigurationSource(): CorsConfigurationSource {
        val configuration = CorsConfiguration()
        val origins = corsAllowedOrigins.split(",")
            .map { it.trim() }
            .filter { it.isNotEmpty() }
            .ifEmpty { listOf("http://localhost:5173") }
        configuration.allowedOrigins = origins
        configuration.allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS")
        configuration.allowedHeaders = listOf("*")
        configuration.allowCredentials = true
        configuration.maxAge = 3600L

        val source = UrlBasedCorsConfigurationSource()
        source.registerCorsConfiguration("/api/**", configuration)
        return source
    }

    @Bean
    fun adminFilterBean(): FilterRegistrationBean<Filter> {
        val filterRegBean = FilterRegistrationBean<Filter>()
        filterRegBean.setFilter(AdminAuthFilter())
        filterRegBean.addUrlPatterns("/admin/*")
        filterRegBean.addUrlPatterns("/docs/*")
        filterRegBean.setOrder(Ordered.LOWEST_PRECEDENCE)
        return filterRegBean
    }

    @Bean
    fun forwardedHeaderFilter(): FilterRegistrationBean<ForwardedHeaderFilter> {
        val filterRegBean = FilterRegistrationBean<ForwardedHeaderFilter>()
        filterRegBean.setFilter(ForwardedHeaderFilter())
        filterRegBean.setOrder(Ordered.HIGHEST_PRECEDENCE)
        return filterRegBean
    }

}
