package com.tistory.shanepark.dutypark.push.apns.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size

data class ApnsInstallationRequest(
    @field:NotBlank
    @field:Size(max = 512)
    val deviceToken: String,

    val sandbox: Boolean = false,
)
