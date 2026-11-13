package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.annotation.MemberNameLength
import jakarta.validation.constraints.NotBlank

data class AuxiliaryAccountCreateRequest(
    @field:NotBlank(message = "member.auxiliary.name.required")
    @field:MemberNameLength
    val name: String? = null,
)
