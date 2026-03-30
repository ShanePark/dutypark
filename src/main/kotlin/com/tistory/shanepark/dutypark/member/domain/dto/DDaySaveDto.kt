package com.tistory.shanepark.dutypark.member.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated
import java.time.LocalDate

@Validated
data class DDaySaveDto(
    var id: Long? = null,
    @field:NotBlank(message = "dday.title.required")
    @field:Size(min = 1, max = 30, message = "dday.title.length")
    val title: String,
    val date: LocalDate,
    val isPrivate: Boolean
)
