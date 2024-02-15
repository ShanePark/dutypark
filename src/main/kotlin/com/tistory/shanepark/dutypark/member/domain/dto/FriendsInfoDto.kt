package com.tistory.shanepark.dutypark.member.domain.dto

data class FriendsInfoDto(
    val friends: List<MemberDto>,
    val pendingRequestsTo: List<FriendRequestDto>,
    val pendingRequestsFrom: List<FriendRequestDto>
)
