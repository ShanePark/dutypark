package com.tistory.shanepark.dutypark.member.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/auth/refresh-tokens")
class RefreshTokenController(
    private val refreshTokenService: RefreshTokenService,
    private val cookieService: CookieService,
) {

    @GetMapping
    fun findAllRefreshTokens(
        @Login loginMember: LoginMember,
        request: HttpServletRequest,
        @RequestParam("validOnly", required = false, defaultValue = "true") validOnly: Boolean,
    ): List<RefreshTokenDto> {
        val refreshTokens = refreshTokenService.findRefreshTokens(loginMember.id, validOnly)
        val currentToken = cookieService.extractRefreshToken(request.cookies)

        refreshTokens
            .firstOrNull { it.token == currentToken }
            ?.isCurrentLogin = true

        return refreshTokens
    }

    @DeleteMapping("/{id}")
    fun deleteRefreshToken(
        @Login loginMember: LoginMember,
        @PathVariable id: Long,
    ): ResponseEntity<Void> {
        refreshTokenService.deleteRefreshToken(loginMember, id)
        return ResponseEntity.noContent().build()
    }

    @DeleteMapping("/others")
    fun deleteOtherRefreshTokens(
        @Login loginMember: LoginMember,
        request: HttpServletRequest,
    ): ResponseEntity<Map<String, Int>> {
        val currentToken = cookieService.extractRefreshToken(request.cookies)
            ?: return ResponseEntity.badRequest().build()
        val deletedCount = refreshTokenService.deleteOtherRefreshTokens(loginMember.id, currentToken)
        return ResponseEntity.ok(mapOf("deletedCount" to deletedCount))
    }

}
