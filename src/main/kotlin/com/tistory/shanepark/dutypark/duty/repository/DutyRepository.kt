package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query

interface DutyRepository : JpaRepository<Duty, Long> {

    @EntityGraph(attributePaths = ["dutyType"])
    fun findAllByMemberAndDutyYearAndDutyMonth(member: Member, year: Int, month: Int): List<Duty>

    fun findByMemberAndDutyYearAndDutyMonthAndDutyDay(member: Member, year: Int, month: Int, day: Int): Duty?

    @Modifying
    @Query("update Duty d set d.dutyType = null where d.dutyType = :dutyType")
    fun setDutyTypeNullIfDutyTypeIs(dutyType: DutyType)

}
