package com.tistory.shanepark.dutypark.security.domain.dto

data class TokenResponse(
    val accessToken: String,
    val refreshToken: String,
    val expiresIn: Long,
    val tokenType: String = "Bearer"
)
