package com.tistory.shanepark.dutypark.security.config

import org.springframework.beans.factory.annotation.Value
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.web.SecurityFilterChain

@Configuration
class SecurityConfig(
    @param:Value("\${spring.profiles.active:default}")
    private val activeProfile: String
) {

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        return http.requiresChannel {
            if (activeProfile != "dev" && activeProfile != "test") {
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
