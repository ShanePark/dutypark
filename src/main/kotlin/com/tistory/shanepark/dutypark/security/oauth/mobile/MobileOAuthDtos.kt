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

/**
 * Credentials returned by a provider's native SDK. Provider tokens deliberately stay out of
 * the response and are never represented in server-side domain objects.
 */
data class MobileOAuthNativeExchangeRequest(
    @field:NotBlank(message = "auth.oauth.mobile.provider.required")
    @field:Size(max = 16, message = "auth.oauth.mobile.provider.invalid")
    val provider: String,

    @field:Size(max = 16, message = "auth.oauth.mobile.purpose.invalid")
    val purpose: String = MobileOAuthPurpose.LOGIN.name,

    @field:Size(max = MAX_PROVIDER_TOKEN_LENGTH, message = "auth.oauth.mobile.native.token.tooLong")
    val accessToken: String? = null,

    @field:Size(max = MAX_PROVIDER_TOKEN_LENGTH, message = "auth.oauth.mobile.native.token.tooLong")
    val refreshToken: String? = null,
) {
    override fun toString(): String =
        "MobileOAuthNativeExchangeRequest(provider=$provider, purpose=$purpose, " +
            "accessToken=${accessToken.redacted()}, refreshToken=${refreshToken.redacted()})"

    private fun String?.redacted(): String = if (this == null) "null" else "[REDACTED]"

    companion object {
        const val MAX_PROVIDER_TOKEN_LENGTH = 2048
    }
}

data class MobileOAuthNativeCapabilitiesResponse(
    val providers: List<String>,
)
