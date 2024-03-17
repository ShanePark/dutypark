package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility

data class MemberDto(
    val id: Long,
    val name: String,
    val email: String? = null,
    val departmentId: Long? = null,
    val department: String? = null,
    val managerId: Long? = null,
    val calendarVisibility: Visibility,
) {
    companion object {
        fun of(member: Member): MemberDto {
            return MemberDto(
                id = member.id!!,
                name = member.name,
                email = member.email,
                departmentId = member.department?.id,
                department = member.department?.name,
                managerId = member.department?.manager?.id,
                calendarVisibility = member.calendarVisibility
            )
        }

        fun ofSimple(member: Member): MemberDto {
            return MemberDto(
                id = member.id!!,
                name = member.name,
                email = member.email,
                calendarVisibility = member.calendarVisibility
            )
        }
    }
}
