package com.tistory.shanepark.dutypark.member.domain.dto

data class VisibleFriendIds(
    val duty: Set<Long>,
    val schedule: Set<Long>,
)
