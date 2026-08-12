package com.tistory.shanepark.dutypark.push.apns.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.push.apns.dto.ApnsInstallationRequest
import com.tistory.shanepark.dutypark.push.apns.service.ApnsInstallationService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import jakarta.validation.Valid
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/auth/push/apns")
class ApnsInstallationController(
    private val apnsInstallationService: ApnsInstallationService,
    private val cookieService: CookieService,
) {
    @PostMapping("/register")
    fun register(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: ApnsInstallationRequest,
        servletRequest: HttpServletRequest,
    ): ResponseEntity<Map<String, Boolean>> {
        val refreshToken = cookieService.extractRefreshToken(servletRequest.cookies)
            ?: throw AuthException("auth.refresh.invalid")
        apnsInstallationService.register(loginMember, refreshToken, request.deviceToken, request.sandbox)
        return ResponseEntity.ok(mapOf("success" to true))
    }

    @PostMapping("/unregister")
    fun unregister(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: ApnsInstallationRequest,
        servletRequest: HttpServletRequest,
    ): ResponseEntity<Map<String, Boolean>> = ResponseEntity.ok(
        mapOf(
            "success" to apnsInstallationService.unregister(
                loginMember,
                cookieService.extractRefreshToken(servletRequest.cookies)
                    ?: throw AuthException("auth.refresh.invalid"),
                request.deviceToken,
            )
        )
    )
}
