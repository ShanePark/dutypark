package com.tistory.shanepark.dutypark.security.controller

import com.fasterxml.jackson.databind.ObjectMapper
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoLoginService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.ResponseEntity
import org.springframework.web.bind.annotation.GetMapping
import org.springframework.web.bind.annotation.RequestMapping
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.bind.annotation.RestController

@RestController
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
    ): ResponseEntity<Any> {
        val curUrl = httpServletRequest.requestURL.toString()
        val state = objectMapper.readValue(stateString, Map::class.java)
        val referer = state["referer"] as String

        // TODO: if it's logged in, then set kakao-id to member

        return kakaoLoginService.login(code = code, redirectUrl = curUrl, referer = referer, req = httpServletRequest)
    }

}
