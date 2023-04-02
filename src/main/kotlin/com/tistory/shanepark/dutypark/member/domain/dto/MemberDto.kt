package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class MemberDto(
    val id: Long,
    val name: String,
    val email: String,
    val department: String?,
) {
    constructor (member: Member) : this(
        id = member.id!!,
        name = member.name,
        email = member.email,
        department = member.department?.name
    )
}
