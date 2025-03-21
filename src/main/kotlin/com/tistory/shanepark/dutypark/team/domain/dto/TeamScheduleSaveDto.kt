package com.tistory.shanepark.dutypark.team.domain.dto

import com.tistory.shanepark.dutypark.common.exceptions.InvalidScheduleTimeRangeExeption
import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import java.time.LocalDateTime
import java.util.*

data class TeamScheduleSaveDto(
    val id: UUID? = null,
    val teamId: Long,

    @field:Length(max = 50) @field:NotBlank
    val content: String,

    @field:Length(max = 4096)
    val description: String = "",

    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
) {

    init {
        if (startDateTime.isAfter(endDateTime)) {
            throw InvalidScheduleTimeRangeExeption()
        }
    }

}
