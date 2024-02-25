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
    companion object {
        fun of(friendRequest: FriendRequest): FriendRequestDto {
            return FriendRequestDto(
                id = friendRequest.id!!,
                fromMember = MemberDto.of(friendRequest.fromMember),
                toMember = MemberDto.of(friendRequest.toMember),
                status = friendRequest.status.name,
                createdAt = friendRequest.createdDate
            )
        }
    }
}
