package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import java.time.LocalDate

data class DutyDto(
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyType: String?,
    val dutyColor: String?,
    val isOff: Boolean,
) {
    constructor(duty: Duty) : this(
        year = duty.dutyDate.year,
        month = duty.dutyDate.monthValue,
        day = duty.dutyDate.dayOfMonth,
        dutyType = duty.dutyType?.name,
        dutyColor = duty.dutyType?.color?.name,
        isOff = duty.dutyType == null
    )

    companion object {
        fun offDuty(date: LocalDate, team: Team): DutyDto {
            return DutyDto(
                year = date.year,
                month = date.monthValue,
                day = date.dayOfMonth,
                dutyType = team.defaultDutyName,
                dutyColor = team.defaultDutyColor.name,
                isOff = true
            )
        }
    }

}
