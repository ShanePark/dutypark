package com.tistory.shanepark.dutypark.security.domain.dto

data class SsoSignupRequest(
    val uuid: String,
    val username: String,
    val termAgree: Boolean
)
