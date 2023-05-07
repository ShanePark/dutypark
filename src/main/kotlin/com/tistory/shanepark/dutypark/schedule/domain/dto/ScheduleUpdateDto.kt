package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.fasterxml.jackson.annotation.JsonIgnore
import jakarta.validation.constraints.AssertTrue
import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import java.time.LocalDateTime

data class ScheduleUpdateDto(
    val memberId: Long,
    @field:Length(max = 30)
    @field:NotBlank
    val content: String,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
) {

    @AssertTrue(message = "StartDateTime must be before or equal to EndDateTime")
    @JsonIgnore
    fun isDateRangeValid(): Boolean {
        return !startDateTime.isAfter(endDateTime)
    }

}
