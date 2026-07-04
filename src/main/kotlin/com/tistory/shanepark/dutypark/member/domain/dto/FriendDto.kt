package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation

data class FriendDto(
    val id: Long,
    val name: String,
    val teamId: Long? = null,
    val team: String? = null,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
    val isFamily: Boolean = false,
    val pinOrder: Long? = null,
)

internal fun FriendRelation.toFriendDto(): FriendDto {
    val preview = friend.toMemberPreviewDto()
    return FriendDto(
        id = preview.id ?: throw IllegalStateException("Member id is null"),
        name = preview.name,
        teamId = preview.teamId,
        team = preview.team,
        hasProfilePhoto = preview.hasProfilePhoto,
        profilePhotoVersion = preview.profilePhotoVersion,
        isFamily = isFamily,
        pinOrder = pinOrder,
    )
}
