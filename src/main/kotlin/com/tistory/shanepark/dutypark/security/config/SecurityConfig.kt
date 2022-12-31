package com.tistory.shanepark.dutypark.security.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.web.SecurityFilterChain

@Configuration
class SecurityConfig {

    @Value("\${spring.profiles.active:default}")
    private lateinit var activeProfile: String

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        return http.requiresChannel {
            if ("dev" != activeProfile) {
                it.anyRequest().requiresSecure()
            }
        }.authorizeHttpRequests()
            .anyRequest()
            .permitAll()
            .and()
            .csrf().disable()
            .build()
    }

    @Bean
    fun passwordEncoder(): PasswordEncoder {
        return BCryptPasswordEncoder()
    }

}
