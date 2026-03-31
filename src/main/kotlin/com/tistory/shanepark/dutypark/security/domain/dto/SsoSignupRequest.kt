package com.tistory.shanepark.dutypark.security.domain.dto

import jakarta.validation.constraints.AssertTrue
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
    @field:AssertTrue(message = "policy.terms.consent.required")
    val termAgree: Boolean,
    @field:AssertTrue(message = "policy.privacy.consent.required")
    val privacyAgree: Boolean,
    @field:NotBlank(message = "policy.terms.version.required")
    val termsVersion: String? = null,
    @field:NotBlank(message = "policy.privacy.version.required")
    val privacyVersion: String? = null,
)
