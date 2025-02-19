package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.department.domain.entity.Department
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.util.*

interface MemberRepository : JpaRepository<Member, Long> {

    @EntityGraph(attributePaths = ["department", "department.dutyTypes"])
    fun findMemberByName(name: String): Member?

    @EntityGraph(attributePaths = ["department"])
    override fun findAll(): MutableList<Member>

    @EntityGraph(attributePaths = ["department"])
    fun findByEmail(email: String?): Optional<Member>

    @EntityGraph(attributePaths = ["department"])
    fun findMembersByNameContainingIgnoreCase(name: String, pageable: Pageable): Page<Member>

    @Query("select m from Member m join fetch m.department d  where m.id = :memberId")
    fun findMemberWithDepartment(memberId: Long): Optional<Member>

    @EntityGraph(attributePaths = ["department"])
    fun findMembersByNameContainingIgnoreCaseAndIdNotIn(
        name: String,
        excludeIds: List<Long?>,
        page: Pageable
    ): Page<Member>

    fun findMemberByKakaoId(kakaoId: String): Member?
    fun findMembersByDepartment(department: Department): List<Member>
}
