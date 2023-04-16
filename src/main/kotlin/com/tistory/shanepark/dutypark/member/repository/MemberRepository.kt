package com.tistory.shanepark.dutypark.member.repository

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
    fun findByEmail(email: String): Optional<Member>

    @EntityGraph(attributePaths = ["department"])
    fun findMembersByNameContainingIgnoreCase(name: String, pageable: Pageable): Page<Member>

    @Query("select m from Member m join fetch m.department d  where m.id = :dutyMemberId")
    fun findMemberWithDepartment(dutyMemberId: Long): Optional<Member>

}
