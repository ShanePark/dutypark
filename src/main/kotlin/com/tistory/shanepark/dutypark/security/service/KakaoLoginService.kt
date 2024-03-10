package com.tistory.shanepark.dutypark.security.service

import org.springframework.stereotype.Service

@Service
class KakaoLoginService {

    val restApiKey = ""
    val kakaoAuthUrl = "https://kauth.kakao.com/oauth/token"
    val userInfoUrl = "https://kapi.kakao.com/v2/user/me"

    fun login(code: String) {
        val contentType = "application/x-www-form-urlencoded"
        val grantType = "authorization_code"
        val redirectUrl = ""

        // 1. get access token

        // 2. load user info with access token

        // 3. with user id, log in or sign up

    }

}
