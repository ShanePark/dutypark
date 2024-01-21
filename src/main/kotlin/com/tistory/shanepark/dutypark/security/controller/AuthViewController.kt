package com.tistory.shanepark.dutypark.security.controller

import com.tistory.shanepark.dutypark.common.controller.ViewController
import com.tistory.shanepark.dutypark.member.domain.annotation.Login
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import jakarta.servlet.http.HttpSession
import org.springframework.http.HttpHeaders
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.CookieValue
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.bind.annotation.RequestMapping

@Controller
@RequestMapping("/auth")
class AuthViewController : ViewController() {

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

}
