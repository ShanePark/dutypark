package com.tistory.shanepark.dutypark.admin.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken

data class AdminMemberDto(
    val id: Long,
    val name: String,
    val email: String?,
    val teamId: Long?,
    val teamName: String?,
    val tokens: List<RefreshTokenDto>,
    val profilePhotoUrl: String? = null,
) {
    companion object {
        fun of(member: Member, tokens: List<RefreshToken>, profilePhotoUrl: String? = null): AdminMemberDto {
            return AdminMemberDto(
                id = member.id!!,
                name = member.name,
                email = member.email,
                teamId = member.team?.id,
                teamName = member.team?.name,
                tokens = tokens.filter { it.isValid() }.map { RefreshTokenDto.of(it) },
                profilePhotoUrl = profilePhotoUrl
            )
        }
    }
}
