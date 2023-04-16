package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class MemberDto(
    val id: Long,
    val name: String,
    val email: String,
    val department: String?,
    val managerId: Long?,
) {
    constructor (member: Member) : this(
        id = member.id!!,
        name = member.name,
        email = member.email,
        department = member.department?.name,
        managerId = member.department?.manager?.id,
    )
}
