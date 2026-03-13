package com.tistory.shanepark.dutypark.member.domain.dto

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
