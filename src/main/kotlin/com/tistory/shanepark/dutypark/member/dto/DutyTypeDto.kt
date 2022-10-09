package com.tistory.shanepark.dutypark.member.dto

import com.tistory.shanepark.dutypark.duty.domain.DutyType

data class DutyTypeDto(
    var id: Long,
    var name: String,
    var index: Int,
) {
    constructor(dutyType: DutyType) : this(
        dutyType.id!!,
        dutyType.name,
        dutyType.index
    )
}
