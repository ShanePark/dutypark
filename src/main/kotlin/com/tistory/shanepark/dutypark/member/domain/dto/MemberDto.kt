package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class MemberDto(
    val id: Long,
    val name: String,
    val department: String
) {
    constructor (member: Member) : this(
        member.id!!,
        member.name,
        member.department.name
    )
}
