package com.tistory.shanepark.dutypark.security.oauth.kakao

import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.service.annotation.GetExchange

interface KakaoAccessTokenInfoApi {

    @GetExchange(value = "/user/access_token_info")
    fun getAccessTokenInfo(
        @RequestHeader("Authorization") accessToken: String,
    ): KakaoAccessTokenInfoResponse
}
