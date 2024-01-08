package com.tistory.shanepark.dutypark.member.domain.dto

import jakarta.validation.constraints.NotBlank
import jakarta.validation.constraints.Size
import org.springframework.validation.annotation.Validated
import java.time.LocalDate

@Validated
data class DDaySaveDto(
    @field:NotBlank
    @field:Size(min = 1, max = 30, message = "D-DAY 제목은 1자 이상 30자 이하로 입력해주세요.")
    val title: String,
    val date: LocalDate,
    val isPrivate: Boolean
)
