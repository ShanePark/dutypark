package com.tistory.shanepark.dutypark.dashboard.domain

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.member.domain.dto.FriendDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto

data class DashboardFriendDetail(
    val member: FriendDto,
    val duty: DutyDto?,
    val schedules: List<ScheduleDto> = emptyList(),
    val isFamily: Boolean = false,
    val pinOrder: Long? = null,
) : Comparable<DashboardFriendDetail> {
    override fun compareTo(other: DashboardFriendDetail): Int {
        return compareValuesBy(
            this, other,
            { it.pinOrder ?: Long.MAX_VALUE },
            { it.member.name }
        )
    }
}
