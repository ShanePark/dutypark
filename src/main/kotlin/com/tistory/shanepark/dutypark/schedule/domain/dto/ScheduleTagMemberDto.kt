package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.member.domain.dto.toMemberPreviewDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility

data class ScheduleTagMemberDto(
    val id: Long?,
    val name: String,
    val teamId: Long?,
    val team: String?,
    val hasProfilePhoto: Boolean,
    val profilePhotoVersion: Long,
) {
    // Older iOS clients require these fields; tags must never expose actual account settings.
    val hasPassword: Boolean = false
    val calendarVisibility: Visibility = Visibility.PRIVATE
}

internal fun Member.toScheduleTagMemberDto(): ScheduleTagMemberDto {
    val preview = toMemberPreviewDto()
    return ScheduleTagMemberDto(
        id = preview.id,
        name = preview.name,
        teamId = preview.teamId,
        team = preview.team,
        hasProfilePhoto = preview.hasProfilePhoto,
        profilePhotoVersion = preview.profilePhotoVersion,
    )
}
