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
    val dutyTypeId: Long? = null,
    val source: DutySource = DutySource.OVERRIDE,
) {
    constructor(duty: Duty) : this(
        year = duty.dutyDate.year,
        month = duty.dutyDate.monthValue,
        day = duty.dutyDate.dayOfMonth,
        dutyType = duty.dutyType?.name,
        dutyColor = dutyColor(duty),
        isOff = duty.dutyType == null,
        dutyTypeId = duty.dutyType?.id,
        source = DutySource.OVERRIDE,
    )

    companion object {
        private fun dutyColor(duty: Duty): String? {
            val dutyType = duty.dutyType
            if (dutyType == null) {
                return duty.member.team?.defaultDutyColor
            }
            return dutyType.color
        }

        fun offDuty(date: LocalDate, team: Team, source: DutySource = DutySource.DEFAULT_OFF): DutyDto {
            return DutyDto(
                year = date.year,
                month = date.monthValue,
                day = date.dayOfMonth,
                dutyType = team.defaultDutyName,
                dutyColor = team.defaultDutyColor,
                isOff = true,
                dutyTypeId = null,
                source = source,
            )
        }
    }

}
