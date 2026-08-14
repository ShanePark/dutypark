package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthPurpose
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

data class AppleNativeExchangeRequest(
    @field:NotBlank(message = "auth.apple.identityToken.required")
    val identityToken: String,
    @field:NotBlank(message = "auth.apple.authorizationCode.required")
    val authorizationCode: String,
    @field:Size(min = 32, max = 128, message = "auth.apple.nonce.invalid")
    val nonce: String,
    val purpose: MobileOAuthPurpose = MobileOAuthPurpose.LOGIN,
)

data class AppleWebExchangeRequest(
    @field:NotBlank(message = "auth.apple.identityToken.required")
    val identityToken: String,
    @field:NotBlank(message = "auth.apple.authorizationCode.required")
    val authorizationCode: String,
    @field:Size(min = 32, max = 128, message = "auth.apple.nonce.invalid")
    val rawNonce: String,
    val purpose: MobileOAuthPurpose = MobileOAuthPurpose.LOGIN,
)

data class AppleTokenResponse(
    val refresh_token: String? = null,
    val id_token: String? = null,
    val error: String? = null,
)

data class AppleJwks(val keys: List<AppleJwk> = emptyList())

data class AppleJwk(
    val kty: String,
    val kid: String,
    val use: String? = null,
    val alg: String? = null,
    val n: String,
    val e: String,
)

data class VerifiedAppleIdentity(
    val subject: String,
    val expiresAtEpochSecond: Long,
)
