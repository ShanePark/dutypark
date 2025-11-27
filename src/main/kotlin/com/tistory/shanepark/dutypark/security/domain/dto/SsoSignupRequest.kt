package com.tistory.shanepark.dutypark.security.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated

@Validated
data class SsoSignupRequest(
    @field:NotBlank
    val uuid: String,
    @field:NotBlank
    @field:Size(min = 1, max = 10, message = "사용자명은 1-10자로 입력해주세요.")
    val username: String,
    val termAgree: Boolean
)
