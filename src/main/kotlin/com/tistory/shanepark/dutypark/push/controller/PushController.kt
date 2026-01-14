package com.tistory.shanepark.dutypark.push.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.push.dto.PushSubscriptionRequest
import com.tistory.shanepark.dutypark.push.service.WebPushService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import jakarta.validation.Valid
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/auth/push")
class PushController(
    private val webPushService: WebPushService,
    private val cookieService: CookieService,
    private val refreshTokenService: RefreshTokenService,
    @Value("\${dutypark.webpush.vapid.public-key:}")
    private val vapidPublicKey: String
) {

    @GetMapping("/vapid-public-key")
    fun getVapidPublicKey(): Map<String, String> {
        return mapOf("publicKey" to vapidPublicKey)
    }

    @GetMapping("/enabled")
    fun isEnabled(): Map<String, Boolean> {
        return mapOf("enabled" to webPushService.isEnabled())
    }

    @PostMapping("/subscribe")
    fun subscribe(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: PushSubscriptionRequest,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Map<String, Boolean>> {
        val refreshToken = getValidRefreshToken(httpRequest, loginMember)
            ?: return ResponseEntity.status(401).body(mapOf("success" to false))

        val success = webPushService.subscribe(refreshToken, request)
        return ResponseEntity.ok(mapOf("success" to success))
    }

    @PostMapping("/unsubscribe")
    fun unsubscribe(
        @Login loginMember: LoginMember,
        httpRequest: HttpServletRequest
    ): ResponseEntity<Map<String, Boolean>> {
        val refreshToken = getValidRefreshToken(httpRequest, loginMember)
            ?: return ResponseEntity.status(401).body(mapOf("success" to false))

        val success = webPushService.unsubscribe(refreshToken)
        return ResponseEntity.ok(mapOf("success" to success))
    }

    private fun getValidRefreshToken(request: HttpServletRequest, loginMember: LoginMember) =
        cookieService.extractRefreshToken(request.cookies)
            ?.let { refreshTokenService.findByToken(it) }
            ?.takeIf { it.member.id == loginMember.id && it.isValid() }
}
