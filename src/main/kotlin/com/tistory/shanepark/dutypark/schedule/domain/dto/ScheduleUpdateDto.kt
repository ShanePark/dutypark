package com.tistory.shanepark.dutypark.schedule.domain.dto

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

    init {
        require(!startDateTime.isAfter(endDateTime)) { "StartDateTime must not be after EndDateTime" }
    }

}
