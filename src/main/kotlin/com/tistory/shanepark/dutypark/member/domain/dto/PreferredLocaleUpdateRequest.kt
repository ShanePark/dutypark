package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.common.config.DutyparkLocale
import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Pattern

data class PreferredLocaleUpdateRequest(
    @field:NotBlank(message = "{member.preferredLocale.required}")
    @field:Pattern(
        regexp = "^(ko|en|ja)$",
        flags = [Pattern.Flag.CASE_INSENSITIVE],
        message = "{member.preferredLocale.unsupported}"
    )
    val preferredLocale: String? = null,
) {
    fun normalizedPreferredLocale(): String {
        return DutyparkLocale.normalize(preferredLocale.orEmpty())
    }
}
