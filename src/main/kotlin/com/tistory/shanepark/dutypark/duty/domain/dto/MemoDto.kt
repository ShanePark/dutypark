package com.tistory.shanepark.dutypark.duty.domain.dto

data class MemoDto(
    val year: Int,
    val month: Int,
    val day: Int,
    val memo: String,
    val memberId: Long,
    val password: String,
) {

}
