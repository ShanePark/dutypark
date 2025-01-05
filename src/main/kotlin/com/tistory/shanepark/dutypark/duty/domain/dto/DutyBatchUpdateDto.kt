package com.tistory.shanepark.dutypark.duty.domain.dto

data class DutyBatchUpdateDto(
    val year: Int,
    val month: Int,
    val dutyTypeId: Long?,
    val memberId: Long,
)
