package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.annotation.MemberNameLength
import jakarta.validation.constraints.NotBlank

class MemberNameUpdateRequest(name: String? = null) {
    // Validate the trimmed value that is actually stored. Kotlin trim also strips characters such as
    // NBSP that @NotBlank keeps, and a blank becomes null so only the "required" violation is reported.
    @field:NotBlank(message = "sso.username.required")
    @field:MemberNameLength
    val name: String? = name?.trim()?.takeIf(String::isNotEmpty)
}
