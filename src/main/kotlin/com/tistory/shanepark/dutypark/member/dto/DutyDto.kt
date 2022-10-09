package com.tistory.shanepark.dutypark.member.dto

import com.tistory.shanepark.dutypark.duty.domain.Duty

data class DutyDto(
    val id: Long,
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyType: DutyTypeDto,
    val memo: String
) {
    constructor(duty: Duty) : this(
        duty.id!!,
        duty.dutyYear,
        duty.dutyMonth,
        duty.dutyDay,
        DutyTypeDto(duty.dutyType),
        duty.memo ?: ""
    )
}
