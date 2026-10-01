package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.domain.dto.DutyParkErrorResponse
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.RateLimitException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import com.tistory.shanepark.dutypark.security.service.LoginAttemptService
import jakarta.validation.Valid
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val authService: AuthService,
    private val cookieService: CookieService,
    private val refreshTokenService: RefreshTokenService,
    private val jwtConfig: JwtConfig,
    private val loginAttemptService: LoginAttemptService,
) {
    companion object {
        private val LOGGABLE_AUTH_CODES = setOf(
            "auth.refresh.invalid", "auth.refresh.expired", "auth.account.inactive", AuthService.SUSPENDED_MESSAGE,
            "auth.impersonation.alreadyImpersonating", "auth.impersonation.managerNotFound",
            "auth.impersonation.targetNotFound", "auth.impersonation.forbidden", "auth.impersonation.sessionInvalid",
            "auth.restore.notImpersonating", "auth.restore.originalMissing", "auth.restore.originalNotFound",
            "auth.restore.sessionInvalid",
        )
    }

    @PutMapping("password")
    fun changePassword(
        @Login loginMember: LoginMember,
        @Valid @RequestBody(required = true) param: PasswordChangeDto
    ): ResponseEntity<Void> {
        if (loginMember.id != param.memberId && !loginMember.isAdmin) {
            throw AuthException("auth.password.changeUnauthorized")
        }
        val byAdmin = loginMember.isAdmin && loginMember.id != param.memberId
        authService.changePassword(param, byAdmin, actor = loginMember)
        return ResponseEntity.noContent().build()
    }

    @GetMapping("/status")
    fun loginStatus(
        @Login(required = false)
        loginMember: LoginMember?
    ): LoginMember? {
        return loginMember
    }

    /**
     * SPA login API with HttpOnly cookies
     */
    @PostMapping("/token")
    fun loginForToken(
        @Valid @RequestBody loginDto: LoginDto,
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<*> {
        return try {
            val tokenResponse = authService.getTokenResponse(loginDto, req)
            cookieService.setTokenCookies(resp, tokenResponse.accessToken, tokenResponse.refreshToken)
            ResponseEntity.ok(tokenResponse.toPublicResponse())
        } catch (e: RateLimitException) {
            recordError(req, "auth.login.rateLimited", e)
            ResponseEntity.status(429).body(
                DutyParkErrorResponse.of(
                    status = 429,
                    code = "auth.login.rateLimited",
                )
            )
        } catch (e: AuthException) {
            recordError(req, if (e.message == AuthService.SUSPENDED_MESSAGE) AuthService.SUSPENDED_MESSAGE else "auth.login.failed", e)
            if (e.message == AuthService.SUSPENDED_MESSAGE) {
                return ResponseEntity.status(401).body(
                    DutyParkErrorResponse.of(
                        status = 401,
                        code = AuthService.SUSPENDED_MESSAGE,
                    )
                )
            }
            val email = loginDto.email ?: ""
            val ipAddress = req.remoteAddr ?: "unknown"
            val remainingAttempts = loginAttemptService.getRemainingAttempts(ipAddress, email)
            ResponseEntity.status(401).body(
                DutyParkErrorResponse.of(
                    status = 401,
                    code = "auth.login.failed",
                    details = mapOf(
                        "remainingAttempts" to remainingAttempts,
                    ),
                )
            )
        }
    }

    /**
     * Token refresh API - reads refresh token from HttpOnly cookie
     */
    @PostMapping("/refresh")
    fun refreshToken(
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<*> {
        val refreshToken = cookieService.extractRefreshToken(req.cookies)
            ?: return unauthorizedRefresh(req, resp, "auth.refresh.invalid")
        return try {
            val tokenResponse = authService.refreshAccessToken(refreshToken, req)
            cookieService.setTokenCookies(resp, tokenResponse.accessToken, tokenResponse.refreshToken)
            ResponseEntity.ok(tokenResponse.toPublicResponse())
        } catch (e: AuthException) {
            recordError(req, safeAuthCode(e.message, "auth.refresh.invalid"), e)
            unauthorizedRefresh(req, resp, e.message ?: "auth.refresh.invalid")
        }
    }

    /**
     * Logout API - clears cookies and invalidates refresh token
     */
    @PostMapping("/logout")
    fun logout(
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<Void> {
        val refreshToken = cookieService.extractRefreshToken(req.cookies)
        try {
            if (refreshToken != null) {
                refreshTokenService.deleteByToken(refreshToken)
            }
        } finally {
            cookieService.clearTokenCookies(resp)
        }
        return ResponseEntity.noContent().build()
    }

    /**
     * Impersonate API - switch to managed account
     * Only sets access token cookie (no refresh token) so impersonation auto-expires
     */
    @PostMapping("/impersonate/{targetMemberId}")
    fun impersonate(
        @Login loginMember: LoginMember,
        @PathVariable targetMemberId: Long,
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<*> {
        return try {
            val refreshToken = cookieService.extractRefreshToken(req.cookies)
            val accessToken = authService.impersonate(loginMember, targetMemberId, refreshToken)
            cookieService.setAccessTokenCookie(resp, accessToken)
            ResponseEntity.ok(mapOf("expiresIn" to jwtConfig.tokenValidityInSeconds))
        } catch (e: AuthException) {
            recordError(req, safeAuthCode(e.message, "auth.impersonation.failed"), e)
            ResponseEntity.status(403).body(
                DutyParkErrorResponse.of(
                    status = 403,
                    code = e.message ?: "auth.impersonation.failed",
                )
            )
        }
    }

    /**
     * Restore API - switch back to original account
     * Reuses existing refresh token from cookie to avoid token accumulation
     */
    @PostMapping("/restore")
    fun restore(
        @Login loginMember: LoginMember,
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<*> {
        return try {
            val existingRefreshToken = cookieService.extractRefreshToken(req.cookies)
            val tokenResponse = authService.restore(loginMember, existingRefreshToken, req)
            cookieService.setTokenCookies(resp, tokenResponse.accessToken, tokenResponse.refreshToken)
            ResponseEntity.ok(tokenResponse.toPublicResponse())
        } catch (e: AuthException) {
            recordError(req, safeAuthCode(e.message, "auth.restore.failed"), e)
            ResponseEntity.status(400).body(
                DutyParkErrorResponse.of(
                    status = 400,
                    code = e.message ?: "auth.restore.failed",
                )
            )
        }
    }

    private fun recordError(req: HttpServletRequest, code: String, error: Exception? = null) {
        req.setAttribute("dutypark.logging.errorCode", code)
        error?.let { req.setAttribute("dutypark.logging.exceptionType", it.javaClass.name) }
    }

    private fun safeAuthCode(candidate: String?, fallback: String): String =
        candidate?.takeIf { it in LOGGABLE_AUTH_CODES } ?: fallback

    private fun TokenResponse.toPublicResponse(): Map<String, Any> {
        return mapOf(
            "expiresIn" to expiresIn
        )
    }

    private fun unauthorizedRefresh(req: HttpServletRequest, resp: HttpServletResponse, code: String): ResponseEntity<DutyParkErrorResponse> {
        recordError(req, safeAuthCode(code, "auth.refresh.invalid"))
        cookieService.clearTokenCookies(resp)
        return ResponseEntity.status(401).body(
            DutyParkErrorResponse.of(
                status = 401,
                code = code,
            )
        )
    }

}
