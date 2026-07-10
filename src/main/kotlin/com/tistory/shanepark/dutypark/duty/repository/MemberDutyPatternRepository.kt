package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.MemberDutyPattern
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository

interface MemberDutyPatternRepository : JpaRepository<MemberDutyPattern, Long> {
    @EntityGraph(attributePaths = ["dutyType", "weekdays"])
    fun findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member: Member): MemberDutyPattern?

    @EntityGraph(attributePaths = ["dutyType", "weekdays"])
    fun findAllByMemberOrderByEffectiveFromDescIdDesc(member: Member): List<MemberDutyPattern>

    @EntityGraph(attributePaths = ["dutyType", "weekdays"])
    fun findAllByMemberInOrderByEffectiveFromDescIdDesc(members: Collection<Member>): List<MemberDutyPattern>

    fun deleteAllByTeam(team: Team)
}
