package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import java.time.LocalDateTime

data class FriendRequestDto(
    val id: Long,
    val fromMember: MemberDto,
    val toMember: MemberDto,
    val status: String,
    val createdAt: LocalDateTime?
) {
    constructor(friendRequest: FriendRequest) : this(
        id = friendRequest.id!!,
        fromMember = MemberDto(friendRequest.fromMember),
        toMember = MemberDto(friendRequest.toMember),
        status = friendRequest.status.name,
        createdAt = friendRequest.createdDate
    )
}
