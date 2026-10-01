package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse

class AuthControllerOutcomeMetadataTest {
    private val auth: AuthService = mock()
    private val cookies: CookieService = mock()
    private val controller = AuthController(auth, cookies, mock(), JwtConfig("secret", 1000, 30), mock())

    @Test
    fun `missing refresh cookie sets safe request outcome error metadata`() {
        val request = MockHttpServletRequest()
        val response = controller.refreshToken(request, MockHttpServletResponse())
        assertThat(response.statusCode.value()).isEqualTo(401)
        assertThat(request.getAttribute("dutypark.logging.errorCode")).isEqualTo("auth.refresh.invalid")
        assertThat(request.getAttribute("dutypark.logging.exceptionType")).isNull()
    }

    @Test
    fun `caught refresh error sets normalized metadata without private exception text`() {
        val request = MockHttpServletRequest()
        whenever(cookies.extractRefreshToken(request.cookies)).thenReturn("private-refresh")
        whenever(auth.refreshAccessToken("private-refresh", request)).thenThrow(AuthException("private access credential in exception"))
        val response = controller.refreshToken(request, MockHttpServletResponse())
        assertThat(response.statusCode.value()).isEqualTo(401)
        assertThat(request.getAttribute("dutypark.logging.errorCode")).isEqualTo("auth.refresh.invalid")
        assertThat(request.getAttribute("dutypark.logging.exceptionType")).isEqualTo(AuthException::class.java.name)
    }
}
