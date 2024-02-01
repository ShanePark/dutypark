package com.tistory.shanepark.dutypark.common.domain.dto

import com.tistory.shanepark.dutypark.common.domain.entity.BaseTimeEntity

data class BaseTimeDto(
    val createdDate: String,
    val modifiedDate: String,
) {
    constructor(baseTime: BaseTimeEntity) : this(
        createdDate = baseTime.createdDate.toString(),
        modifiedDate = baseTime.modifiedDate.toString(),
    )
}
