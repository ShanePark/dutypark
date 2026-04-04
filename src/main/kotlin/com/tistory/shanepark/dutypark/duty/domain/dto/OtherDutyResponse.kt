package com.tistory.shanepark.dutypark.duty.domain.dto

class OtherDutyResponse(
    val memberId: Long,
    val name: String,
    val hasProfilePhoto: Boolean,
    val profilePhotoVersion: Long,
    val duties: List<DutyDto>
)
