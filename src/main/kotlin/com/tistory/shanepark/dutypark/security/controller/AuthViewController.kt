package com.tistory.shanepark.dutypark.security.controller

import jakarta.servlet.http.HttpSession
import org.springframework.http.HttpHeaders
import org.springframework.stereotype.Controller
import org.springframework.ui.Model
import org.springframework.web.bind.annotation.*

@Controller
class AuthViewController {

    @GetMapping("/login")
    fun loginPage(
        @CookieValue(name = "rememberMe", required = false) rememberMe: String?,
        @RequestHeader(HttpHeaders.REFERER, required = false) referer: String?,
        httpSession: HttpSession,
        model: Model
    ): String {
        rememberMe?.let {
            model.addAttribute("rememberMe", rememberMe)
        }
        referer?.let {
            httpSession.setAttribute("referer", referer)
        }
        return "member/login"
    }

}
