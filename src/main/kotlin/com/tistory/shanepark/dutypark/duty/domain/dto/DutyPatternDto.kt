package com.tistory.shanepark.dutypark.duty.domain.dto

import jakarta.validation.constraints.NotEmpty
import java.time.DayOfWeek

data class DutyPatternUpdateDto(
    @field:NotEmpty
    val weekdays: Set<DayOfWeek>,
    val holidayOff: Boolean,
)

data class DutyPatternDutyTypeDto(
    val id: Long,
    val name: String,
    val color: String,
)

data class DutyPatternDetailsDto(
    val weekdays: Set<DayOfWeek>,
    val holidayOff: Boolean,
    val effectiveFrom: String,
)

data class DutyPatternDto(
    val configurable: Boolean,
    val reason: String?,
    val dutyType: DutyPatternDutyTypeDto?,
    val pattern: DutyPatternDetailsDto?,
)
