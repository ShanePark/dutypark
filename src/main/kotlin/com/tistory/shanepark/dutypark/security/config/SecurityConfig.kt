package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.filters.AdminAuthFilter
import com.tistory.shanepark.dutypark.security.filters.JwtAuthFilter
import com.tistory.shanepark.dutypark.security.handlers.LogoutSuccessHandle
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.Filter
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.web.servlet.FilterRegistrationBean
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.core.Ordered
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.access.intercept.AuthorizationFilter
import org.springframework.web.filter.ForwardedHeaderFilter

@Configuration
class SecurityConfig(
    private val logoutHandler: LogoutSuccessHandle,
    private val authService: AuthService,
    private val jwtConfig: JwtConfig,
    @param:Value("\${dutypark.ssl.enabled}") private val isSecure: Boolean
) {

    private val log = logger()

    init {
        log.info("jwtConfig: $jwtConfig")
        log.info("isSecure: $isSecure")
    }

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        val jwtAuthFilter = JwtAuthFilter(authService, jwtConfig, isSecure = isSecure)
        http.addFilterBefore(jwtAuthFilter, AuthorizationFilter::class.java)

        return http
            .authorizeHttpRequests { it.anyRequest().permitAll() }
            .logout { it.logoutUrl("/logout").logoutSuccessHandler(logoutHandler) }
            .csrf { it.disable() }
            .build()
    }

    @Bean
    fun adminFilterBean(): FilterRegistrationBean<Filter> {
        val filterRegBean = FilterRegistrationBean<Filter>()
        filterRegBean.filter = AdminAuthFilter()
        filterRegBean.addUrlPatterns("/admin/*")
        filterRegBean.addUrlPatterns("/docs/*")
        filterRegBean.order = Ordered.LOWEST_PRECEDENCE
        return filterRegBean
    }

    @Bean
    fun forwardedHeaderFilter(): FilterRegistrationBean<ForwardedHeaderFilter> {
        val filterRegBean = FilterRegistrationBean<ForwardedHeaderFilter>()
        filterRegBean.filter = ForwardedHeaderFilter()
        filterRegBean.order = Ordered.HIGHEST_PRECEDENCE
        return filterRegBean
    }

}
