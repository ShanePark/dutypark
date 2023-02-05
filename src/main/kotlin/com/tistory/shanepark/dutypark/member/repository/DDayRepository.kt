package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query

interface DDayRepository : JpaRepository<DDayEvent, Long> {
    fun countByMember(member: Member): Long
    fun findAllByMemberOrderByPosition(member: Member): List<DDayEvent>

    @Query("select coalesce(max(d.position),-1) from DDayEvent d where d.member = :member")
    fun findMaxPositionByMember(member: Member): Long
}
