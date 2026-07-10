package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query

interface DutyTypeRepository : JpaRepository<DutyType, Long> {

    @Query("select dt.team.id from DutyType dt where dt.id = :dutyTypeId")
    fun findTeamIdById(dutyTypeId: Long): Long?

    fun findAllByTeam(team: Team): List<DutyType>

    fun findAllByTeamAndHiddenFalse(team: Team): List<DutyType>

    fun findAllByTeamInAndHiddenFalse(teams: Collection<Team>): List<DutyType>
}
