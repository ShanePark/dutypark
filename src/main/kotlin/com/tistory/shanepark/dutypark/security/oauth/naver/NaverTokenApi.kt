package com.tistory.shanepark.dutypark.security.oauth.naver

import org.springframework.http.MediaType
import org.springframework.web.bind.annotation.RequestParam
import org.springframework.web.service.annotation.PostExchange

interface NaverTokenApi {

    @PostExchange(value = "/token", contentType = MediaType.APPLICATION_FORM_URLENCODED_VALUE)
    fun getAccessToken(
        @RequestParam("grant_type") grantType: String,
        @RequestParam("client_id") clientId: String,
        @RequestParam("client_secret") clientSecret: String,
        @RequestParam("code") code: String,
        @RequestParam("state") state: String
    ): NaverTokenResponse
}
