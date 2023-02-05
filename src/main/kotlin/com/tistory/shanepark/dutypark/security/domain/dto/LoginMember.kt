package com.tistory.shanepark.dutypark.security.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member

data class LoginMember(
    val id: Long,
    val email: String,
    val name: String,
    val departmentId: Long?,
    val departmentName: String,
) {
    companion object {
        fun from(member: Member): LoginMember {
            return LoginMember(
                id = member.id!!,
                email = member.email,
                name = member.name,
                departmentId = member.department.id,
                departmentName = member.department.name
            )
        }
    }
}
