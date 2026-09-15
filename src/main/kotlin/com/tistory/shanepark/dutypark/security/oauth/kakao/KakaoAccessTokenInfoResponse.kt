package com.tistory.shanepark.dutypark.security.oauth.kakao

import com.fasterxml.jackson.annotation.JsonProperty

data class KakaoAccessTokenInfoResponse(
    @JsonProperty("id")
    val id: Long? = null,

    @JsonProperty("expires_in")
    val expiresIn: Long? = null,

    @JsonProperty("app_id")
    val appId: Long? = null,
)
