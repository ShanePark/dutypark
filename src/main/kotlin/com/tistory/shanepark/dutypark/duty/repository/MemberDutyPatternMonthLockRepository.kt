package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPatternMonthLock
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import java.time.LocalDate

interface MemberDutyPatternMonthLockRepository : JpaRepository<MemberDutyPatternMonthLock, Long> {
    @EntityGraph(attributePaths = ["pattern", "pattern.dutyType", "pattern.weekdays", "baselineWorkDates"])
    fun findAllByMemberAndYearMonthBetween(member: Member, from: LocalDate, to: LocalDate): List<MemberDutyPatternMonthLock>

    @EntityGraph(attributePaths = ["pattern", "pattern.dutyType", "pattern.weekdays", "baselineWorkDates"])
    fun findAllByMemberInAndYearMonth(
        members: Collection<Member>,
        yearMonth: LocalDate,
    ): List<MemberDutyPatternMonthLock>

    fun existsByMemberAndTeamAndYearMonth(member: Member, team: Team, yearMonth: LocalDate): Boolean

    fun deleteAllByTeam(team: Team)
}
