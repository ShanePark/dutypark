package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty

data class DutyDto(
    val id: Long? = null,
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyType: String?,
    val dutyColor: String?,
) {
    constructor(duty: Duty) : this(
        duty.id,
        duty.dutyYear,
        duty.dutyMonth,
        duty.dutyDay,
        duty.dutyType?.name,
        duty.dutyType?.color?.name,
    )
}
