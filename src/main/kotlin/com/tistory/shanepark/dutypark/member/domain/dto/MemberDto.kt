package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class MemberDto(
    val id: Long,
    val name: String,
    val email: String,
    val departmentId: Long?,
    val department: String?,
    val managerId: Long?,
) {
    constructor (member: Member) : this(
        id = member.id!!,
        name = member.name,
        email = member.email,
        departmentId = member.department?.id,
        department = member.department?.name,
        managerId = member.department?.manager?.id,
    )
}
