package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestType
import java.time.LocalDateTime

data class FriendRequestDto(
    val id: Long,
    val fromMember: MemberPreviewDto,
    val toMember: MemberPreviewDto,
    val status: String,
    val createdAt: LocalDateTime?,
    val requestType: FriendRequestType,
)

internal fun FriendRequest.toFriendRequestDto(): FriendRequestDto {
    return FriendRequestDto(
        id = id ?: throw IllegalStateException("FriendRequest id is null"),
        fromMember = fromMember.toMemberPreviewDto(),
        toMember = toMember.toMemberPreviewDto(),
        status = status.name,
        createdAt = createdDate,
        requestType = requestType,
    )
}
