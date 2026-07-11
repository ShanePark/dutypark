package com.tistory.shanepark.dutypark.duty.domain.dto

import jakarta.validation.constraints.NotEmpty
import jakarta.validation.constraints.NotNull
import jakarta.validation.Valid
import java.time.DayOfWeek

data class DutyPatternDayUpdateDto(
    val weekday: DayOfWeek,
    @field:NotNull
    val dutyTypeId: Long?,
)

data class DutyPatternUpdateDto(
    @field:NotEmpty
    @field:Valid
    val days: List<DutyPatternDayUpdateDto>,
    val holidayOff: Boolean,
) {
    constructor(weekdays: Set<DayOfWeek>, holidayOff: Boolean) : this(
        days = weekdays.map { DutyPatternDayUpdateDto(it, null) },
        holidayOff = holidayOff,
    )
}

data class DutyPatternDutyTypeDto(
    val id: Long,
    val name: String,
    val color: String,
)

data class DutyPatternDetailsDto(
    val days: List<DutyPatternDayDto>,
    val holidayOff: Boolean,
    val effectiveFrom: String,
)

data class DutyPatternDayDto(
    val weekday: DayOfWeek,
    val dutyType: DutyPatternDutyTypeDto,
)

data class DutyPatternDto(
    val configurable: Boolean,
    val reason: String?,
    val dutyTypes: List<DutyPatternDutyTypeDto>,
    val pattern: DutyPatternDetailsDto?,
)
