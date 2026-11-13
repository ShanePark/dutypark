package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility

/**
 * A member on the other side of a manager relationship. It must never carry account identifiers
 * such as email or social IDs. calendarVisibility and hasPassword remain only because released
 * iOS builds decode this list as MemberDTO, where both are required fields.
 */
data class ManagerMemberDto(
    val id: Long?,
    val name: String,
    val teamId: Long? = null,
    val team: String? = null,
    val calendarVisibility: Visibility,
    val hasPassword: Boolean = false,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
)

internal fun Member.toManagerMemberDto(): ManagerMemberDto {
    val preview = toMemberPreviewDto()
    return ManagerMemberDto(
        id = preview.id,
        name = preview.name,
        teamId = preview.teamId,
        team = preview.team,
        calendarVisibility = calendarVisibility,
        hasPassword = !password.isNullOrBlank(),
        hasProfilePhoto = preview.hasProfilePhoto,
        profilePhotoVersion = preview.profilePhotoVersion,
    )
}
