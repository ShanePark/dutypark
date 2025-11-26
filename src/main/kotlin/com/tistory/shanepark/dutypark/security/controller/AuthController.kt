package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
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
) {
    private val log = logger()

    @PutMapping("password")
    fun changePassword(
        @Login loginMember: LoginMember,
        @RequestBody(required = true) param: PasswordChangeDto
    ): ResponseEntity<String> {
        if (loginMember.id != param.memberId && !loginMember.isAdmin) {
            throw AuthException("You are not authorized to change this password")
        }
        val byAdmin = loginMember.isAdmin && loginMember.id != param.memberId
        authService.changePassword(param, byAdmin)
        return ResponseEntity.ok().body("Password Changed")
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
        @RequestBody loginDto: LoginDto,
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<*> {
        return try {
            val tokenResponse = authService.getTokenResponse(loginDto, req)
            cookieService.setTokenCookies(resp, tokenResponse.accessToken, tokenResponse.refreshToken)
            ResponseEntity.ok(tokenResponse.toPublicResponse())
        } catch (e: AuthException) {
            ResponseEntity.status(401).body(mapOf("error" to (e.message ?: "로그인에 실패했습니다.")))
        }
    }

    /**
     * Token refresh API - reads refresh token from HttpOnly cookie
     */
    @PostMapping("/refresh")
    fun refreshToken(
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<Map<String, Any>> {
        val refreshToken = cookieService.extractRefreshToken(req.cookies)
            ?: return ResponseEntity.status(401).build()
        return try {
            val tokenResponse = authService.refreshAccessToken(refreshToken, req)
            cookieService.setTokenCookies(resp, tokenResponse.accessToken, tokenResponse.refreshToken)
            ResponseEntity.ok(tokenResponse.toPublicResponse())
        } catch (e: AuthException) {
            cookieService.clearTokenCookies(resp)
            ResponseEntity.status(401).build()
        }
    }

    /**
     * Logout API - clears cookies and invalidates refresh token
     */
    @PostMapping("/logout")
    fun logout(
        @Login loginMember: LoginMember,
        req: HttpServletRequest,
        resp: HttpServletResponse
    ): ResponseEntity<Void> {
        val refreshToken = cookieService.extractRefreshToken(req.cookies)
        if (refreshToken != null) {
            val token = refreshTokenService.findByToken(refreshToken)
            if (token != null && token.member.id == loginMember.id) {
                refreshTokenService.deleteByToken(refreshToken)
            }
        }
        cookieService.clearTokenCookies(resp)
        return ResponseEntity.noContent().build()
    }

    private fun TokenResponse.toPublicResponse(): Map<String, Any> {
        return mapOf(
            "expiresIn" to expiresIn
        )
    }

}
