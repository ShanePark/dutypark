package com.tistory.shanepark.dutypark.security.oauth.naver

import org.springframework.web.bind.annotation.RequestHeader
import org.springframework.web.service.annotation.GetExchange

interface NaverUserInfoApi {

    @GetExchange("/nid/me")
    fun getUserInfo(
        @RequestHeader("Authorization") accessToken: String
    ): NaverUserInfoResponse
}
