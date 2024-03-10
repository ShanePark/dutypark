package com.tistory.shanepark.dutypark.security.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.security.service.KakaoLoginService
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
        @RequestParam(name = "state", required = true) stateString: String
    ): String {
        kakaoLoginService.login(code)

        val state = objectMapper.readValue(stateString, Map::class.java)
        val referer = state["referer"]
        return "redirect:$referer"
    }

}
