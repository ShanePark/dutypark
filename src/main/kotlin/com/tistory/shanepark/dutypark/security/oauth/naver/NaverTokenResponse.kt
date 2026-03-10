package com.tistory.shanepark.dutypark.security.oauth.naver

import com.fasterxml.jackson.annotation.JsonProperty

data class NaverTokenResponse(
    @param:JsonProperty("access_token")
    val accessToken: String? = null,

    @param:JsonProperty("refresh_token")
    val refreshToken: String? = null,

    @param:JsonProperty("token_type")
    val tokenType: String? = null,

    @param:JsonProperty("expires_in")
    val expiresIn: String? = null,

    val error: String? = null,

    @param:JsonProperty("error_description")
    val errorDescription: String? = null,
)
