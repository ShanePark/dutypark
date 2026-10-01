package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.CookieConfig
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.Cookie
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.springframework.mock.web.MockHttpServletRequest

class RefreshTokenControllerUnitTest {

    @Test
    fun `delete other refresh tokens passes authenticated actor to service`() {
        val refreshTokenService = mock<RefreshTokenService>()
        val cookieService = CookieService(
            cookieConfig = CookieConfig(secure = false, sameSite = "Lax", domain = null),
            jwtConfig = JwtConfig(secret = "secret", tokenValidityInSeconds = 600, refreshTokenValidityInDays = 7),
        )
        val controller = RefreshTokenController(refreshTokenService, cookieService)
        val actor = LoginMember(id = 17L, name = "Session Owner")
        val currentRefreshToken = "current-refresh-token-secret"
        val request = MockHttpServletRequest().apply {
            setCookies(Cookie(CookieService.REFRESH_TOKEN_COOKIE, currentRefreshToken))
        }

        val result = controller.deleteOtherRefreshTokens(actor, request)

        assertThat(result.body?.get("deletedCount")).isEqualTo(0)
        verify(refreshTokenService).deleteOtherRefreshTokens(17L, currentRefreshToken, actor)
    }
}
