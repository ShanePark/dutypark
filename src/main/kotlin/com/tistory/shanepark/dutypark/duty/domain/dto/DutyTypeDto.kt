package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType

data class DutyTypeDto(
    var id: Long,
    var name: String,
    var position: Int,
    var color: String,
) {
    constructor(dutyType: DutyType) : this(
        dutyType.id!!,
        dutyType.name,
        dutyType.position,
        dutyType.color.name
    )
}
