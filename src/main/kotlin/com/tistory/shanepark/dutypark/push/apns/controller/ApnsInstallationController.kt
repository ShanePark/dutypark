package com.tistory.shanepark.dutypark.push.apns.controller

import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.push.apns.dto.ApnsInstallationRequest
import com.tistory.shanepark.dutypark.push.apns.service.ApnsInstallationService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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
) {
    @PostMapping("/register")
    fun register(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: ApnsInstallationRequest,
    ): ResponseEntity<Map<String, Boolean>> {
        apnsInstallationService.register(loginMember.id, request.deviceToken, request.sandbox)
        return ResponseEntity.ok(mapOf("success" to true))
    }

    @PostMapping("/unregister")
    fun unregister(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: ApnsInstallationRequest,
    ): ResponseEntity<Map<String, Boolean>> = ResponseEntity.ok(
        mapOf("success" to apnsInstallationService.unregister(loginMember.id, request.deviceToken))
    )
}
