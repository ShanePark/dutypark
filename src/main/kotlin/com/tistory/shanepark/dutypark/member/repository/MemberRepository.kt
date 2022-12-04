package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository

interface MemberRepository : JpaRepository<Member, Long> {

    @EntityGraph(attributePaths = ["department", "department.dutyTypes"])
    fun findMemberByName(name: String): Member?

    @EntityGraph(attributePaths = ["department"])
    override fun findAll(): MutableList<Member>

}
