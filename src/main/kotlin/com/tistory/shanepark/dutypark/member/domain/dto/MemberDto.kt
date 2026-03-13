package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
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

internal fun Member.toMemberDto(kakaoId: String? = null, naverId: String? = null): MemberDto {
    val preview = toMemberPreviewDto()
    return MemberDto(
        id = preview.id,
        name = preview.name,
        email = email,
        teamId = preview.teamId,
        team = preview.team,
        calendarVisibility = calendarVisibility,
        kakaoId = kakaoId,
        naverId = naverId,
        hasPassword = password != null,
        hasProfilePhoto = preview.hasProfilePhoto,
        profilePhotoVersion = preview.profilePhotoVersion,
    )
}
