package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.jpa.repository.JpaRepository

interface DutyTypeRepository : JpaRepository<DutyType, Long> {

    fun findAllByTeam(team: Team): List<DutyType>
}
