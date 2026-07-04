package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class MemberInviteCandidateDto(
    val id: Long?,
    val name: String,
    val email: String? = null,
    val teamId: Long? = null,
    val team: String? = null,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
)

internal fun Member.toMemberInviteCandidateDto(): MemberInviteCandidateDto {
    return MemberInviteCandidateDto(
        id = id,
        name = name,
        email = email,
        teamId = team?.id,
        team = team?.name,
        hasProfilePhoto = hasProfilePhoto(),
        profilePhotoVersion = profilePhotoVersion,
    )
}
