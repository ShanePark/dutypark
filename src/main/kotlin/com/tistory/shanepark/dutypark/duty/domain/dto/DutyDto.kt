package com.tistory.shanepark.dutypark.duty.domain.dto

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
    companion object {
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
