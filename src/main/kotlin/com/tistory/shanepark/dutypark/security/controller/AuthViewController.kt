package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpSession
import org.springframework.http.HttpHeaders
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.*

@Controller
@RequestMapping("/auth")
class AuthViewController(
    private val authService: AuthService
) : ViewController() {

    @GetMapping("login")
    fun loginPage(
        @CookieValue(name = "rememberMe", required = false) rememberMe: String?,
        @RequestHeader(HttpHeaders.REFERER, required = false) referer: String?,
        @Login(required = false) loginMember: LoginMember?,
        httpSession: HttpSession,
        model: Model
    ): String {
        loginMember?.let {
            return "redirect:/"
        }

        rememberMe?.let {
            model.addAttribute("rememberMe", rememberMe)
        }
        referer?.let {
            httpSession.setAttribute("referer", referer)
        }
        return layout(model, "member/login")
    }

    @GetMapping("/sso-signup")
    fun ssoSignupPage(@RequestParam uuid: String, model: Model): String {
        authService.validateSsoRegister(uuid)
        model.addAttribute("uuid", uuid)
        return layout(model, "member/sso-signup")
    }

    @GetMapping("/sso-congrats")
    fun ssoCongratsPage(@Login loginMember: LoginMember, model: Model): String {
        model.addAttribute("member_name", loginMember.name)
        model.addAttribute("member_id", loginMember.id)
        return layout(model, "member/sso-congrats")
    }

}
