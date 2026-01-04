package com.tistory.shanepark.dutypark.team.domain.dto

import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team

data class TeamDto(
    val id: Long,
    val name: String,
    val description: String?,
    val workType: String,
    val dutyTypes: List<DutyTypeDto>,
    val members: List<TeamMemberDto>,
    val createdDate: String,
    val lastModifiedDate: String,
    val adminId: Long?,
    val adminName: String?,
    val dutyBatchTemplate: DutyBatchTemplateDto?
) {
    override fun equals(other: Any?): Boolean {
        if (this === other) return true
        if (other !is TeamDto) return false
        if (this.id != other.id) return false
        return true
    }

    override fun hashCode(): Int {
        return id.hashCode()
    }

    companion object {
        fun ofSimple(team: Team): TeamDto {
            return of(team, mutableListOf(), mutableListOf())
        }

        fun of(
            team: Team,
            members: List<Member>,
            dutyTypes: List<DutyType>,
            profilePhotoUrls: Map<Long, String?> = emptyMap()
        ): TeamDto {
            val sortedTypes = dutyTypes.sortedBy { it.position }
                .map {
                    DutyTypeDto(
                        it.id,
                        it.name,
                        it.position,
                        it.color.toString()
                    )
                }.toMutableList()
            sortedTypes.add(
                0,
                DutyTypeDto(
                    name = team.defaultDutyName,
                    position = -1,
                    color = team.defaultDutyColor.toString()
                )
            )

            return TeamDto(
                id = team.id ?: -1L,
                name = team.name,
                description = team.description,
                workType = team.workType.name,
                dutyTypes = sortedTypes,
                members = members.map { member ->
                    TeamMemberDto.of(team, member, profilePhotoUrls[member.id])
                },
                createdDate = team.createdDate.toString(),
                lastModifiedDate = team.lastModifiedDate.toString(),
                adminName = team.admin?.name,
                adminId = team.admin?.id,
                dutyBatchTemplate = team.dutyBatchTemplate?.let { DutyBatchTemplateDto(it) }
            )
        }
    }

}
