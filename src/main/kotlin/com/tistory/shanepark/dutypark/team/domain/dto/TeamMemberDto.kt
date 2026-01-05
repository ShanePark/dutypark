package com.tistory.shanepark.dutypark.team.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team

data class TeamMemberDto(
    val id: Long?,
    val name: String,
    val email: String?,
    val isManager: Boolean,
    val isAdmin: Boolean,
    val hasProfilePhoto: Boolean = false,
    val profilePhotoVersion: Long = 0,
) {
    companion object {
        fun of(team: Team, member: Member): TeamMemberDto {
            return TeamMemberDto(
                id = member.id,
                name = member.name,
                email = member.email,
                isManager = team.isManager(member.id),
                isAdmin = team.isAdmin(member.id),
                hasProfilePhoto = member.hasProfilePhoto(),
                profilePhotoVersion = member.profilePhotoVersion,
            )
        }
    }
}
