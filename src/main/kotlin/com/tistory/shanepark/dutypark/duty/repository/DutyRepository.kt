package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.stereotype.Repository

interface DutyRepository : JpaRepository<Duty, Long> {

    @EntityGraph(attributePaths = ["dutyType"])
    fun findAllByMemberAndDutyYearAndDutyMonth(member: Member, year: Int, month: Int): List<Duty>

    fun findByMemberAndDutyYearAndDutyMonthAndDutyDay(member: Member, year: Int, month: Int, day: Int): Duty?
}
