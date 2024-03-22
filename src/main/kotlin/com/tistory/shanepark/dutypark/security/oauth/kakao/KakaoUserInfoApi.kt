package com.tistory.shanepark.dutypark.security.oauth.kakao

import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.service.annotation.GetExchange

interface KakaoUserInfoApi {

    @GetExchange(value = "/user/me")
    fun getUserInfo(
        @RequestHeader("Authorization") accessToken: String
    ): KakaoUserInfoResponse

}
