package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.handlers.LogoutSuccessHandle
import org.springframework.beans.factory.annotation.Value
import org.springframework.boot.context.properties.EnableConfigurationProperties
import org.springframework.context.annotation.Bean
import org.springframework.context.annotation.Configuration
import org.springframework.security.config.annotation.web.builders.HttpSecurity
import org.springframework.security.crypto.bcrypt.BCryptPasswordEncoder
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.security.web.SecurityFilterChain
import org.springframework.security.web.authentication.logout.LogoutSuccessHandler

@Configuration
@EnableConfigurationProperties(JwtConfig::class, DutyparkProperties::class)
class SecurityConfig(
    @param:Value("\${spring.profiles.active:default}")
    private val activeProfile: String,
    private val logoutHandler: LogoutSuccessHandle
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
            .logout().logoutUrl("/logout")
            .logoutSuccessHandler(logoutHandler)
            .and()
            .csrf().disable()
            .build()
    }

    @Bean
    fun passwordEncoder(): PasswordEncoder {
        return BCryptPasswordEncoder()
    }

}
