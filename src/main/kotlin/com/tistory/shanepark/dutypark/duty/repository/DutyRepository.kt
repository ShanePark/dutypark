package com.tistory.shanepark.dutypark.duty.repository

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import org.springframework.data.jpa.repository.EntityGraph
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Modifying
import org.springframework.data.jpa.repository.Query
import java.time.LocalDate

interface DutyRepository : JpaRepository<Duty, Long> {

    @EntityGraph(attributePaths = ["dutyType"])
    fun findAllByMemberAndDutyDateBetween(member: Member, start: LocalDate, end: LocalDate): List<Duty>

    fun findByMemberAndDutyDate(member: Member, dutyDate: LocalDate): Duty?

    fun deleteDutiesByMemberAndDutyDateBetween(member: Member, start: LocalDate, end: LocalDate)

    fun findByDutyDateAndMemberIn(dutyDate: LocalDate, members: List<Member>): List<Duty>

    fun deleteAllByDutyTypeIn(dutyTypes: List<DutyType>)

}
