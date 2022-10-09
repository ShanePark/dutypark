package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.Duty
import com.tistory.shanepark.dutypark.member.domain.Member
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

@Repository
interface DutyRepository : JpaRepository<Duty, Long> {
    fun findAllByMemberAndDutyYearAndDutyMonth(member: Member, year: Int, month: Int): List<Duty>
}
