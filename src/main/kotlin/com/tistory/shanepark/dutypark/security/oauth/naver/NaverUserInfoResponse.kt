package com.tistory.shanepark.dutypark.security.oauth.naver

import com.fasterxml.jackson.annotation.JsonProperty

data class NaverUserInfoResponse(
    @param:JsonProperty("resultcode")
    val resultCode: String,
    val message: String,
    val response: NaverUserInfoPayload,
)

data class NaverUserInfoPayload(
    val id: String,
)
