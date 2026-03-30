package com.tistory.shanepark.dutypark.security.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated

@Validated
data class SsoSignupRequest(
    @field:NotBlank(message = "sso.uuid.required")
    val uuid: String,
    @field:NotBlank(message = "sso.username.required")
    @field:Size(min = 1, max = 10, message = "sso.username.length")
    val username: String,
    val termAgree: Boolean,
    val privacyAgree: Boolean,
    val termsVersion: String? = null,
    val privacyVersion: String? = null
)
