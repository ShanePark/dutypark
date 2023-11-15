package com.tistory.shanepark.dutypark.member.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated
import java.time.LocalDate

@Validated
data class DDaySaveDto(
    @field:NotBlank
    @field:Size(min = 1, max = 30, message = "title length must be between 1 and 30")
    val title: String,
    val date: LocalDate,
    val isPrivate: Boolean
)
