package com.tistory.shanepark.dutypark.schedule.domain.dto

import jakarta.validation.constraints.AssertTrue
import org.hibernate.validator.constraints.Length
import java.time.LocalDateTime

data class ScheduleUpdateDto(
    val memberId: Long,
    @field:Length(max = 30)
    val content: String,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
) {

    @AssertTrue(message = "StartDateTime must be before or equal to EndDateTime")
    fun isDateRangeValid(): Boolean {
        return !startDateTime.isAfter(endDateTime)
    }

}
