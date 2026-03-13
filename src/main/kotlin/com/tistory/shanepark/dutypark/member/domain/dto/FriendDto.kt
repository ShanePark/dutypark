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
) {
    companion object {
        fun of(relation: FriendRelation): FriendDto {
            val friend = relation.friend
            return FriendDto(
                id = friend.id ?: throw IllegalStateException("Friend id is null"),
                name = friend.name,
                teamId = friend.team?.id,
                team = friend.team?.name,
                hasProfilePhoto = friend.hasProfilePhoto(),
                profilePhotoVersion = friend.profilePhotoVersion,
                isFamily = relation.isFamily,
                pinOrder = relation.pinOrder,
            )
        }
    }
}
