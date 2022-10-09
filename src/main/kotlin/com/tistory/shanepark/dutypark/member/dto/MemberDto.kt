package com.tistory.shanepark.dutypark.member.dto

import com.tistory.shanepark.dutypark.member.domain.Member

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
