package com.tistory.shanepark.dutypark.duty.domain.dto

import jakarta.validation.constraints.NotNull

data class DutyTypeVisibilityDto(
    @field:NotNull
    val hidden: Boolean,
)
