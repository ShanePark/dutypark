package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.security.filters.AdminAuthFilter
import com.tistory.shanepark.dutypark.security.filters.JwtAuthFilter
import com.tistory.shanepark.dutypark.security.filters.OriginCheckFilter
import com.tistory.shanepark.dutypark.security.oauth.OAuthFrontendBaseUrl
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
import org.springframework.web.filter.CorsFilter
import java.net.URI

@Configuration
class SecurityConfig(
    private val authService: AuthService,
    private val cookieService: CookieService,
    private val cookieConfig: CookieConfig,
    private val frontendBaseUrl: OAuthFrontendBaseUrl,
    @param:Value("\${dutypark.cors.allowed-origins:}") private val corsAllowedOrigins: String,
    @param:Value("\${dutypark.cors.allowed-origin-patterns:}") private val corsAllowedOriginPatterns: String,
) {

    private val log = logger()

    init {
        log.info("Init SecurityConfig. corsAllowedOrigins: $corsAllowedOrigins")
    }

    @Bean
    fun filterChain(http: HttpSecurity): SecurityFilterChain {
        val jwtAuthFilter = JwtAuthFilter(authService, cookieService)
        http.addFilterBefore(jwtAuthFilter, AuthorizationFilter::class.java)
        // Ahead of CORS so a rejected cross-site write gets the standard error body; preflights pass through.
        http.addFilterBefore(OriginCheckFilter(stateChangingRequestOrigins()), CorsFilter::class.java)

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
        val origins = csv(corsAllowedOrigins)
        val originPatterns = csv(corsAllowedOriginPatterns)
        validateCorsOrigins(origins, originPatterns)
        configuration.allowedOrigins = origins
        if (originPatterns.isNotEmpty()) {
            configuration.allowedOriginPatterns = originPatterns
        }
        configuration.allowedMethods = listOf("GET", "POST", "PUT", "DELETE", "PATCH", "OPTIONS")
        configuration.allowedHeaders = listOf("*")
        configuration.allowCredentials = true
        configuration.maxAge = 3600L

        val source = UrlBasedCorsConfigurationSource()
        source.registerCorsConfiguration("/api/**", configuration)
        return source
    }

    /**
     * CORS allowlist plus the site's own web origin. Production serves the web app same-origin from
     * DOMAIN_NAME and leaves the CORS allowlist empty, so its origin must be added explicitly.
     */
    private fun stateChangingRequestOrigins(): CorsConfiguration {
        val configuration = CorsConfiguration()
        configuration.allowedOrigins = csv(corsAllowedOrigins) + frontendBaseUrl.origin
        val originPatterns = csv(corsAllowedOriginPatterns)
        if (originPatterns.isNotEmpty()) {
            configuration.allowedOriginPatterns = originPatterns
        }
        return configuration
    }

    private fun csv(value: String): List<String> = value.split(",")
        .map { it.trim() }
        .filter { it.isNotEmpty() }

    private fun validateCorsOrigins(origins: List<String>, originPatterns: List<String>) {
        check("*" !in origins) {
            "Credentialed CORS must not allow every origin"
        }
        if (cookieConfig.secure) {
            check(originPatterns.none { '*' in it }) {
                "Production credentialed CORS must not use wildcard origin patterns"
            }
            check((origins + originPatterns).all { it.startsWith("https://") }) {
                "Production credentialed CORS origins must use HTTPS"
            }
            check((origins + originPatterns).all(::isExactOrigin)) {
                "Production credentialed CORS entries must be exact origins without paths, queries, or fragments"
            }
        }
    }

    private fun isExactOrigin(value: String): Boolean = runCatching {
        val uri = URI(value)
        uri.scheme.equals("https", ignoreCase = true) &&
            uri.host != null &&
            uri.rawUserInfo == null &&
            uri.rawPath.isNullOrEmpty() &&
            uri.rawQuery == null &&
            uri.rawFragment == null &&
            uri.port <= 65535
    }.getOrDefault(false)

    @Bean
    fun adminFilterBean(): FilterRegistrationBean<Filter> {
        val filterRegBean = FilterRegistrationBean<Filter>()
        filterRegBean.setFilter(AdminAuthFilter())
        filterRegBean.addUrlPatterns("/admin/*")
        filterRegBean.addUrlPatterns("/docs/*")
        filterRegBean.setOrder(Ordered.LOWEST_PRECEDENCE)
        return filterRegBean
    }

}
