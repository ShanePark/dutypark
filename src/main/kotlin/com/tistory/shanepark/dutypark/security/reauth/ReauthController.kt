package com.tistory.shanepark.dutypark.security.reauth

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.validation.Valid
import org.springframework.web.bind.annotation.PostMapping
import org.springframework.web.bind.annotation.RequestBody
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RestController

@RestController
@RequestMapping("/api/auth/reauth")
class ReauthController(
    private val authService: AuthService,
    private val reauthService: ReauthService,
) {
    @PostMapping("/password")
    fun reauthenticateWithPassword(
        @Login loginMember: LoginMember,
        @Valid @RequestBody request: PasswordReauthRequest,
    ): ReauthProofResponse {
        if (loginMember.isImpersonating) {
            throw AuthException("auth.reauth.impersonationForbidden")
        }
        authService.verifyPasswordForReauth(loginMember.id, request.password)
        return reauthService.issue(loginMember.id, request.purpose)
    }
}
