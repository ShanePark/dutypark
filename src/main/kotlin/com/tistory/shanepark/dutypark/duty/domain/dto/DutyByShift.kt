package com.tistory.shanepark.dutypark.duty.domain.dto

import com.tistory.shanepark.dutypark.member.domain.dto.SimpleMemberDto

data class DutyByShift(
    val dutyType: DutyTypeDto,
    val members: List<SimpleMemberDto>
)
