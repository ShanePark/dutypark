package com.tistory.shanepark.dutypark.team.repository

import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.domain.entity.TeamSchedule
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime
import java.util.*

interface TeamScheduleRepository : JpaRepository<TeamSchedule, UUID> {

    @Query(
        "select s from TeamSchedule s " +
                "join fetch s.createMember cm " +
                "join fetch s.updateMember um " +
                "where s.team = :team " +
                "and (s.startDateTime <= :end and s.endDateTime >= :start)"
    )
    fun findTeamSchedulesOfTeamRangeIn(
        team: Team,
        start: LocalDateTime,
        end: LocalDateTime
    ): List<TeamSchedule>

}
