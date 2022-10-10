package com.tistory.shanepark.dutypark.member.dto

import com.tistory.shanepark.dutypark.duty.domain.Duty

data class DutyDto(
    val id: Long,
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyType: String,
    val dutyColor: String,
    val memo: String,
) {
    constructor(duty: Duty) : this(
        duty.id!!,
        duty.dutyYear,
        duty.dutyMonth,
        duty.dutyDay,
        duty.dutyType.name,
        duty.dutyType.color.name,
        duty.memo ?: ""
    )
}
