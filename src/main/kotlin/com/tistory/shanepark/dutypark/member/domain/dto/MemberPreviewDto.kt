package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class MemberPreviewDto(
    val id: Long?,
    val name: String,
    val teamId: Long? = null,
    val team: String? = null,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
)

internal fun Member.toMemberPreviewDto(): MemberPreviewDto {
    return MemberPreviewDto(
        id = id,
        name = name,
        teamId = team?.id,
        team = team?.name,
        hasProfilePhoto = hasProfilePhoto(),
        profilePhotoVersion = profilePhotoVersion,
    )
}
