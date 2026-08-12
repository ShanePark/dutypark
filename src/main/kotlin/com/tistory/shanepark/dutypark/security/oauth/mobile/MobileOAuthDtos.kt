package com.tistory.shanepark.dutypark.security.oauth.mobile

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern
import jakarta.validation.constraints.Size

data class MobileOAuthAuthorizeRequest(
    @field:NotBlank(message = "auth.oauth.mobile.provider.required")
    val provider: String,

    val purpose: String = MobileOAuthPurpose.LOGIN.name,

    @field:NotBlank(message = "auth.oauth.mobile.callback.required")
    val callbackUri: String,

    @field:Pattern(
        regexp = "^[A-Za-z0-9_-]{43}$",
        message = "auth.oauth.mobile.pkce.challenge.invalid"
    )
    val codeChallenge: String,
)

enum class MobileOAuthPurpose {
    LOGIN,
    LINK,
    DELETE_ACCOUNT,
}

data class MobileOAuthAuthorizeResponse(
    val authorizationUrl: String,
    val expiresIn: Long,
)

data class MobileOAuthExchangeRequest(
    @field:NotBlank(message = "auth.oauth.mobile.code.required")
    val code: String,

    @field:Size(min = 43, max = 128, message = "auth.oauth.mobile.pkce.verifier.invalid")
    @field:Pattern(
        regexp = "^[A-Za-z0-9._~-]+$",
        message = "auth.oauth.mobile.pkce.verifier.invalid"
    )
    val codeVerifier: String,

    @field:NotBlank(message = "auth.oauth.mobile.callback.required")
    val callbackUri: String,
)

data class MobileOAuthExchangeResponse(
    val signupRequired: Boolean,
    val signupUuid: String? = null,
    val expiresIn: Long? = null,
    val reauthProof: String? = null,
)
