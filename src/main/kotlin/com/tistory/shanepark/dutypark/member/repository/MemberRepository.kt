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

    @Query(
        """
        SELECT m FROM Member m
        LEFT JOIN RefreshToken r ON r.member = m AND r.validUntil > CURRENT_TIMESTAMP
        GROUP BY m
        ORDER BY MAX(r.lastUsed) DESC NULLS LAST, m.name ASC
        """,
        countQuery = "SELECT COUNT(m) FROM Member m"
    )
    fun findAllOrderByLastTokenAccess(pageable: Pageable): Page<Member>

    @Query(
        """
        SELECT m FROM Member m
        LEFT JOIN RefreshToken r ON r.member = m AND r.validUntil > CURRENT_TIMESTAMP
        WHERE LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%'))
        GROUP BY m
        ORDER BY MAX(r.lastUsed) DESC NULLS LAST, m.name ASC
        """,
        countQuery = "SELECT COUNT(m) FROM Member m WHERE LOWER(m.name) LIKE LOWER(CONCAT('%', :keyword, '%'))"
    )
    fun findByNameContainingOrderByLastTokenAccess(keyword: String, pageable: Pageable): Page<Member>
}
