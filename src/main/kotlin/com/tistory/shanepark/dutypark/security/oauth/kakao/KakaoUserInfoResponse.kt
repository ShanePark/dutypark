package com.tistory.shanepark.dutypark.security.oauth.kakao

import com.fasterxml.jackson.annotation.JsonProperty

data class KakaoUserInfoResponse(
    @JsonProperty("id")
    val id: Long,

    @JsonProperty("connected_at")
    val connectedAt: String,
)
