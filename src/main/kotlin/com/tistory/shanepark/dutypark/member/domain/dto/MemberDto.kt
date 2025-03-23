package com.tistory.shanepark.dutypark.member.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility

data class MemberDto(
    val id: Long?,
    val name: String,
    val email: String? = null,
    val teamId: Long? = null,
    val team: String? = null,
    val calendarVisibility: Visibility,
    val kakaoId: String?,
    val hasPassword: Boolean = false
) {
    companion object {
        fun of(member: Member): MemberDto {
            return MemberDto(
                id = member.id!!,
                name = member.name,
                email = member.email,
                teamId = member.team?.id,
                team = member.team?.name,
                calendarVisibility = member.calendarVisibility,
                kakaoId = member.kakaoId,
                hasPassword = member.password != null
            )
        }

        fun ofSimple(member: Member): MemberDto {
            return MemberDto(
                id = member.id,
                name = member.name,
                email = member.email,
                calendarVisibility = member.calendarVisibility,
                kakaoId = member.kakaoId,
                hasPassword = member.password != null
            )
        }
    }
}
