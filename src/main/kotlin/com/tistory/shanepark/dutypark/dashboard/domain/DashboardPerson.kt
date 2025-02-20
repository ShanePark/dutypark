package com.tistory.shanepark.dutypark.dashboard.domain

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto

data class DashboardPerson(
    val member: MemberDto,
    val duty: DutyDto?,
    val schedules: List<ScheduleDto> = emptyList(),
    val isFamily: Boolean = false,
)
