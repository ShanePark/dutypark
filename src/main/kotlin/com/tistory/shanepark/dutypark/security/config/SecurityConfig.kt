package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.filters.AdminAuthFilter
import com.tistory.shanepark.dutypark.security.filters.JwtAuthFilter
import com.tistory.shanepark.dutypark.security.handlers.LogoutSuccessHandle
import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.access.intercept.AuthorizationFilter
import org.springframework.security.web.util.matcher.AntPathRequestMatcher
import org.springframework.security.web.util.matcher.NegatedRequestMatcher

@Configuration
class SecurityConfig(
    @Value("\${server.ssl.enabled}") private val isSecure: Boolean,
    private val logoutHandler: LogoutSuccessHandle,
    private val jwtAuthFilter: JwtAuthFilter,
) {

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        http.requiresChannel {
            if (isSecure) {
                it.requestMatchers(NegatedRequestMatcher(AntPathRequestMatcher("/.well-known/**")))
                    .requiresSecure()
            }
        }

        http.addFilterBefore(jwtAuthFilter, AuthorizationFilter::class.java)
            .addFilterAfter(AdminAuthFilter(), JwtAuthFilter::class.java)

        http.authorizeHttpRequests()
            .anyRequest()
            .permitAll()

        http.logout().logoutUrl("/logout")
            .logoutSuccessHandler(logoutHandler)
            .and()
            .csrf().disable()

        return http.build()
    }

}
