package com.tistory.shanepark.dutypark.dashboard.domain

import com.tistory.shanepark.dutypark.member.domain.dto.FriendRequestDto

data class DashboardFriendInfo(
    val friends: List<DashboardFriendDetail>,
    val pendingRequestsTo: List<FriendRequestDto>,
    val pendingRequestsFrom: List<FriendRequestDto>
)
