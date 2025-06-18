package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType

data class DutyTypeDto(
    val id: Long? = null,
    val name: String,
    val position: Int,
    val color: String?,
) {
    constructor(dutyType: DutyType) : this(
        dutyType.id,
        dutyType.name,
        dutyType.position,
        dutyType.color.name
    )
}
