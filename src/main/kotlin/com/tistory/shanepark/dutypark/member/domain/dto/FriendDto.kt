package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class FriendDto(
    val id: Long?,
    val name: String,
    val teamId: Long? = null,
    val team: String? = null,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
) {
    companion object {
        fun of(member: Member): FriendDto {
            return FriendDto(
                id = member.id!!,
                name = member.name,
                teamId = member.team?.id,
                team = member.team?.name,
                hasProfilePhoto = member.hasProfilePhoto(),
                profilePhotoVersion = member.profilePhotoVersion,
            )
        }
    }
}
