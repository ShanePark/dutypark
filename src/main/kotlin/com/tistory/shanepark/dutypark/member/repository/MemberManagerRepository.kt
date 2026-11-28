package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface MemberManagerRepository : JpaRepository<MemberManager, UUID> {

    fun findAllByManagerAndManaged(manager: Member, managed: Member): List<MemberManager>

    @EntityGraph(attributePaths = ["manager", "manager.team"])
    fun findAllByManaged(member: Member): List<MemberManager>

    @EntityGraph(attributePaths = ["managed", "managed.team"])
    fun findAllByManager(manager: Member): List<MemberManager>
}
