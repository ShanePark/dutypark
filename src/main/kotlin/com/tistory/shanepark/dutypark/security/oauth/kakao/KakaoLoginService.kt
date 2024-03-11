package com.tistory.shanepark.dutypark.security.oauth.kakao

import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service

@Service
class KakaoLoginService(
    private val kakaoTokenApi: KakaoTokenApi,
    private val kakaoUserInfoApi: KakaoUserInfoApi,
    @Value("\${oauth.kakao.rest-api-key}") private val restApiKey: String
) {
    fun login(code: String, redirectUrl: String) {
        // 1. get access token
        val kakaoTokenResponse = kakaoTokenApi.getToken(
            grantType = "authorization_code",
            clientId = restApiKey,
            redirectUri = redirectUrl,
            code = code
        )

        // 2. load user info with access token
        val userinfo = kakaoUserInfoApi.getUserInfo(accessToken = "Bearer ${kakaoTokenResponse.accessToken}")

        // 3. TODO: with user id, log in or sign up
        val kakaoId = userinfo.id
        System.err.println("kakaoId = ${kakaoId}")

    }

}
