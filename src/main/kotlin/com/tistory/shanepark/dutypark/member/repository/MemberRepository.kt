package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.*

interface MemberRepository : JpaRepository<Member, Long> {

    @EntityGraph(attributePaths = ["team", "team.dutyTypes"])
    fun findMemberByName(name: String): Member?

    @EntityGraph(attributePaths = ["team"])
    override fun findAll(): MutableList<Member>

    @EntityGraph(attributePaths = ["team"])
    fun findByEmail(email: String?): Optional<Member>

    @EntityGraph(attributePaths = ["team"])
    fun findMembersByNameContainingIgnoreCaseAndTeamIsNull(name: String, pageable: Pageable): Page<Member>

    @Query("select m from Member m left join fetch m.team d  where m.id = :memberId")
    fun findMemberWithTeam(memberId: Long): Optional<Member>

    @EntityGraph(attributePaths = ["team"])
    fun findMembersByNameContainingIgnoreCaseAndIdNotIn(
        name: String,
        excludeIds: List<Long?>,
        page: Pageable
    ): Page<Member>

    fun findMemberByKakaoId(kakaoId: String): Member?
    fun findMembersByTeam(team: Team): List<Member>
}
