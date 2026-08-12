package com.tistory.shanepark.dutypark.security.reauth

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

data class PasswordReauthRequest(
    val purpose: ReauthPurpose,

    @field:NotBlank(message = "auth.reauth.password.required")
    @field:Size(max = 100, message = "auth.reauth.password.invalid")
    val password: String,
)

data class ReauthProofResponse(
    val reauthProof: String,
    val expiresIn: Long,
)
