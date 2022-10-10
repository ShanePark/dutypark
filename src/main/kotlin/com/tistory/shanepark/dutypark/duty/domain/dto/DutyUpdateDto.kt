package com.tistory.shanepark.dutypark.duty.domain.dto

data class DutyUpdateDto(
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyTypeId: Long?,
    val memberId: Long,
    val password: String,
) {

}
