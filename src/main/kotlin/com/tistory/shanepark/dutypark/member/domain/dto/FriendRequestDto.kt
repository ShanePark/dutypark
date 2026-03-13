package com.tistory.shanepark.dutypark.member.domain.dto

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
