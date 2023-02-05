package com.tistory.shanepark.dutypark.member.domain.dto

import java.time.LocalDate

data class DDaySaveDto(
    val title: String,
    val date: LocalDate,
    val isPrivate: Boolean
)
