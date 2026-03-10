package com.tistory.shanepark.dutypark.security.oauth.naver

import com.fasterxml.jackson.annotation.JsonProperty

data class NaverTokenResponse(
    @param:JsonProperty("access_token")
    val accessToken: String,

    @param:JsonProperty("refresh_token")
    val refreshToken: String? = null,

    @param:JsonProperty("token_type")
    val tokenType: String,

    @param:JsonProperty("expires_in")
    val expiresIn: String
)
