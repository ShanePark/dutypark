package com.tistory.shanepark.dutypark.duty.domain.dto

data class DutyUpdateDto(
    val year: Int,
    val month: Int,
    val day: Int,
    val dutyTypeId: Long?,
    val memberId: Long,
) {
    override fun toString(): String {
        return "DutyUpdateDto(year=$year, month=$month, day=$day, dutyTypeId=$dutyTypeId, memberId=$memberId)"
    }
}
