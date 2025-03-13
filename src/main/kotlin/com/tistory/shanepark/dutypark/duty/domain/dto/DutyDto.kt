package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty

data class DutyDto(
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyType: String? = null,
    val dutyColor: String?,
) {
    constructor(duty: Duty) : this(
        year = duty.dutyDate.year,
        month = duty.dutyDate.monthValue,
        day = duty.dutyDate.dayOfMonth,
        dutyType = duty.dutyType.name,
        dutyColor = duty.dutyType.color?.name,
    )

}
