package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.filters.ActuatorFilter
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
import org.springframework.security.web.util.matcher.AntPathRequestMatcher
import org.springframework.security.web.util.matcher.NegatedRequestMatcher

@Configuration
class SecurityConfig(
    @Value("\${server.ssl.enabled}") private val isSecure: Boolean,
    private val logoutHandler: LogoutSuccessHandle,
    private val dutyparkProperties: DutyparkProperties,
    private val authService: AuthService,
    private val jwtConfig: JwtConfig
) {
    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        http.requiresChannel {
            if (isSecure) {
                it.requestMatchers(NegatedRequestMatcher(AntPathRequestMatcher("/.well-known/**")))
                    .requiresSecure()
            }
        }

        val jwtAuthFilter = JwtAuthFilter(authService, jwtConfig, isSecure)
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
    fun actuatorFilterBean(): FilterRegistrationBean<Filter> {
        val filterRegBean = FilterRegistrationBean<Filter>()
        filterRegBean.filter = ActuatorFilter(dutyparkProperties.whiteIpList)
        filterRegBean.addUrlPatterns("/actuator/*")
        filterRegBean.order = Ordered.HIGHEST_PRECEDENCE
        return filterRegBean
    }

}
