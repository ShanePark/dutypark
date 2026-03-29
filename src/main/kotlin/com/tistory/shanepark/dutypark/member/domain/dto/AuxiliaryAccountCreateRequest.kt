package com.tistory.shanepark.dutypark.member.domain.dto

import jakarta.validation.constraints.NotBlank

data class AuxiliaryAccountCreateRequest(
    @field:NotBlank(message = "{member.auxiliary.name.required}")
    val name: String? = null,
)
