package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val authService: AuthService,
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
        // 자기 자신의 비밀번호 변경 시에는 admin이라도 현재 비밀번호 검증 필요
        val byAdmin = loginMember.isAdmin && loginMember.id != param.memberId
        authService.changePassword(param, byAdmin)
        return ResponseEntity.ok().body("Password Changed")
    }

    @GetMapping("/status")
    fun loginStatus(
        @Login(required = false)
        loginMember: LoginMember?
    ): LoginMember? {
        log.info("Login Member: $loginMember")
        return loginMember
    }

    /**
     * SPA용 Bearer 토큰 로그인 API
     * 쿠키 대신 JSON body로 토큰을 반환합니다.
     */
    @PostMapping("/token")
    fun loginForToken(
        @RequestBody loginDto: LoginDto,
        req: HttpServletRequest
    ): ResponseEntity<*> {
        return try {
            val tokenResponse = authService.getTokenResponse(loginDto, req)
            ResponseEntity.ok(tokenResponse)
        } catch (e: AuthException) {
            ResponseEntity.status(401).body(mapOf("error" to (e.message ?: "로그인에 실패했습니다.")))
        }
    }

    /**
     * SPA용 토큰 갱신 API
     * Refresh token으로 새 Access token을 발급받습니다.
     */
    @PostMapping("/refresh")
    fun refreshToken(
        @RequestBody body: Map<String, String>,
        req: HttpServletRequest
    ): ResponseEntity<TokenResponse> {
        val refreshToken = body["refreshToken"]
            ?: return ResponseEntity.badRequest().build()
        return try {
            val tokenResponse = authService.refreshAccessToken(refreshToken, req)
            ResponseEntity.ok(tokenResponse)
        } catch (e: AuthException) {
            ResponseEntity.status(401).build()
        }
    }

}
