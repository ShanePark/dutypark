package com.tistory.shanepark.dutypark.team.domain.dto

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
        require(!startDateTime.isAfter(endDateTime)) { "StartDateTime must not be after EndDateTime" }
    }

}
