package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.ResponseEntity
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.*

@RestController
@RequestMapping("/api/auth")
class AuthController(
    private val authService: AuthService,
) {
    private val log = logger()

    @PostMapping("login")
    fun login(
        @RequestBody loginDto: LoginDto,
        model: Model,
        req: HttpServletRequest,
        @RequestParam(name = "referer", required = false) urlReferer: String?,
        @SessionAttribute(name = "referer", required = false) referer: String?
    ): ResponseEntity<String> {
        var refererValue = urlReferer ?: referer ?: "/"
        if (refererValue.contains("/login")) {
            refererValue = "/"
        }
        return try {
            val headers = authService.getLoginCookieHeaders(login = loginDto, req = req, referer = refererValue)
            ResponseEntity.ok().headers(headers).body(refererValue)
        } catch (e: AuthException) {
            ResponseEntity.status(401).body(e.message)
        }
    }


    @PutMapping("password")
    fun changePassword(
        @Login loginMember: LoginMember,
        @RequestBody(required = true) param: PasswordChangeDto
    ): ResponseEntity<String> {
        if (loginMember.id != param.memberId && !loginMember.isAdmin) {
            throw AuthException("You are not authorized to change this password")
        }
        authService.changePassword(param, loginMember.isAdmin)
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

}
