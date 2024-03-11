package com.tistory.shanepark.dutypark.security.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoLoginService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.stereotype.Controller
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam

@Controller
@RequestMapping("/api/auth")
class OAuthController(
    private val kakaoLoginService: KakaoLoginService
) {
    private val objectMapper = ObjectMapper()

    @GetMapping("Oauth2ClientCallback/kakao")
    fun kakaoLoginCallback(
        @RequestParam code: String,
        @RequestParam(value = "state") stateString: String,
        httpServletRequest: HttpServletRequest
    ): String {
        val curUrl = httpServletRequest.requestURL.toString()
        kakaoLoginService.login(code, redirectUrl = curUrl)

        val state = objectMapper.readValue(stateString, Map::class.java)
        val referer = state["referer"]

        return "redirect:/$referer"
    }

}
