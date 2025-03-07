package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import org.springframework.data.jpa.repository.JpaRepository
import java.util.*

interface MemberManagerRepository : JpaRepository<MemberManager, UUID> {

    fun findAllByManagerAndManaged(manager: Member, managed: Member): List<MemberManager>
    fun findAllByManaged(member: Member): List<MemberManager>
}
