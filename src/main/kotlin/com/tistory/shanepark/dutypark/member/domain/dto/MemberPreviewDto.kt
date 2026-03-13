package com.tistory.shanepark.dutypark.member.domain.dto

data class MemberPreviewDto(
    val id: Long?,
    val name: String,
    val teamId: Long? = null,
    val team: String? = null,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
)
