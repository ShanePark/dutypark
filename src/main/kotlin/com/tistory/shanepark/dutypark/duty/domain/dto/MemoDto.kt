package com.tistory.shanepark.dutypark.duty.domain.dto

data class MemoDto(
    val year: Int,
    val month: Int,
    val day: Int,
    val memo: String,
    val memberId: Long,
    val password: String,
) {
    override fun toString(): String {
        return "MemoDto(year=$year, month=$month, day=$day, memo='$memo', memberId=$memberId)"
    }
}
