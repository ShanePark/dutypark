package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.exceptions.InvalidScheduleTimeRangeExeption
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import java.time.LocalDateTime
import java.util.*

data class ScheduleSaveDto(
    val id: UUID? = null,
    val memberId: Long,

    @field:Length(max = 50) @field:NotBlank
    val content: String,

    @field:Length(max = 4096)
    val description: String = "",

    val visibility: Visibility = Visibility.FRIENDS,
    val startDateTime: LocalDateTime,
    val endDateTime: LocalDateTime,
    val attachmentSessionId: UUID? = null,
) {

    init {
        if (startDateTime.isAfter(endDateTime)) {
            throw InvalidScheduleTimeRangeExeption()
        }
    }

}
