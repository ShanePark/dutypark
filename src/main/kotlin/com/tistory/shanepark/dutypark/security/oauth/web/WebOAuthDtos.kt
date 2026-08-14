package com.tistory.shanepark.dutypark.security.oauth.web

data class WebOAuthAuthorizeRequest(
    val provider: String,
    val purpose: String,
    val referer: String = "/",
)

data class WebOAuthAuthorizeResponse(
    val authorizationUrl: String,
    val expiresIn: Long,
)

enum class WebOAuthPurpose {
    LOGIN,
    LINK,
}
