package com.tistory.shanepark.dutypark.security.config

import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.mock
import org.springframework.mock.web.MockHttpServletRequest

class SecurityConfigTest {

    @Test
    fun `production credentialed CORS rejects wildcard origin patterns`() {
        val config = securityConfig(
            allowedOrigins = "https://dutypark.example.com",
            allowedOriginPatterns = "https://*.example.com",
            cookieConfig = CookieConfig(secure = true, sameSite = "Lax", domain = "dutypark.example.com"),
        )

        assertThrows<IllegalStateException> {
            config.corsConfigurationSource()
        }
    }

    @Test
    fun `production credentialed CORS rejects insecure origins`() {
        val config = securityConfig(
            allowedOrigins = "http://dutypark.example.com",
            cookieConfig = CookieConfig(secure = true, sameSite = "Lax", domain = "dutypark.example.com"),
        )

        assertThrows<IllegalStateException> {
            config.corsConfigurationSource()
        }
    }

    @Test
    fun `production credentialed CORS rejects URL paths`() {
        val config = securityConfig(
            allowedOrigins = "https://dutypark.example.com/app",
            cookieConfig = CookieConfig(secure = true, sameSite = "Lax", domain = "dutypark.example.com"),
        )

        assertThrows<IllegalStateException> {
            config.corsConfigurationSource()
        }
    }

    @Test
    fun `production credentialed CORS accepts an exact HTTPS allowlist`() {
        val config = securityConfig(
            allowedOrigins = "https://dutypark.example.com",
            cookieConfig = CookieConfig(secure = true, sameSite = "Lax", domain = "dutypark.example.com"),
        )

        val cors = config.corsConfigurationSource().getCorsConfiguration(
            MockHttpServletRequest("GET", "/api/auth/status")
        )

        assertThat(cors?.allowedOrigins).containsExactly("https://dutypark.example.com")
        assertThat(cors?.allowCredentials).isTrue()
    }

    private fun securityConfig(
        allowedOrigins: String = "",
        allowedOriginPatterns: String = "",
        cookieConfig: CookieConfig = CookieConfig(secure = false, sameSite = "Lax"),
    ) = SecurityConfig(
        authService = mock<AuthService>(),
        cookieService = mock<CookieService>(),
        cookieConfig = cookieConfig,
        corsAllowedOrigins = allowedOrigins,
        corsAllowedOriginPatterns = allowedOriginPatterns,
    )
}
