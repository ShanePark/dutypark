package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.DutyAbbreviation
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType

data class DutyTypeDto(
    val id: Long? = null,
    val teamId: Long,
    val name: String,
    val position: Int,
    val color: String?,
    val hidden: Boolean = false,
    val abbreviation: String? = null,
) {
    val shortName: String
        get() = DutyAbbreviation.resolve(name, abbreviation)

    constructor(dutyType: DutyType) : this(
        dutyType.id,
        dutyType.team.id!!,
        dutyType.name,
        dutyType.position,
        dutyType.color,
        dutyType.hidden,
        dutyType.abbreviation,
    )
}
