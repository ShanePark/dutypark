package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.enums.Visibility

data class MemberDto(
    val id: Long?,
    val name: String,
    val email: String? = null,
    val teamId: Long? = null,
    val team: String? = null,
    val calendarVisibility: Visibility,
    val kakaoId: String?,
    val naverId: String?,
    val hasPassword: Boolean = false,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
)
