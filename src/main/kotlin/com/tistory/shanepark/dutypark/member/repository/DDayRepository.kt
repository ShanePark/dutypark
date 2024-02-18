package com.tistory.shanepark.dutypark.member.repository

import com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.JpaRepository

interface DDayRepository : JpaRepository<DDayEvent, Long> {
    fun findAllByMemberOrderByDate(member: Member): List<DDayEvent>

}
