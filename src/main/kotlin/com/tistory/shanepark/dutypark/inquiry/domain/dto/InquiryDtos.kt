package com.tistory.shanepark.dutypark.inquiry.domain.dto

import jakarta.validation.constraints.Email
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import java.util.UUID

data class CreateInquiryRequest(
    @field:NotBlank @field:Email @field:Size(max = 255) val email: String,
    @field:Size(max = 100) val subject: String? = null,
    @field:NotBlank @field:Size(max = 2000) val content: String,
)

data class CreateInquiryResponse(
    val id: UUID,
)
