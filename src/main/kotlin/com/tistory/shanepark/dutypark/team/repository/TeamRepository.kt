package com.tistory.shanepark.dutypark.team.repository

import com.tistory.shanepark.dutypark.team.domain.dto.SimpleTeamDto
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.*

interface TeamRepository : JpaRepository<Team, Long> {

    override fun findById(id: Long): Optional<Team>

    @Query("select new com.tistory.shanepark.dutypark.team.domain.dto.SimpleTeamDto(t.id, t.name, t.description, count(m)) from Team t left join t.members m group by t")
    fun findAllWithMemberCount(pageable: Pageable): Page<SimpleTeamDto>

    fun findByName(name: String): Team?

    @Query("select t from Team t left join fetch t.dutyTypes where t.id = :teamId")
    fun findByIdWithDutyTypes(teamId: Long): Optional<Team>

    @Query("select t from Team t left join fetch t.members where t.id = :teamId")
    fun findByIdWithMembers(teamId: Long): Optional<Team>

}
