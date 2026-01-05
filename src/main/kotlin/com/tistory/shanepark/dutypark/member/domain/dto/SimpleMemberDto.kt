package com.tistory.shanepark.dutypark.member.domain.dto

data class SimpleMemberDto(
    val id: Long,
    val name: String,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
)
