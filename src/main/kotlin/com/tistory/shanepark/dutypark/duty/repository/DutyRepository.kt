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

    @EntityGraph(attributePaths = ["dutyType"])
    fun findByMemberAndDutyDate(member: Member, dutyDate: LocalDate): Duty?

    @Modifying(flushAutomatically = true)
    @Query("delete from Duty d where d.member = :member and d.dutyDate between :start and :end")
    fun deleteDutiesByMemberAndDutyDateBetween(member: Member, start: LocalDate, end: LocalDate)

    fun deleteByMemberAndDutyDate(member: Member, dutyDate: LocalDate)

    @Modifying(flushAutomatically = true)
    @Query("delete from Duty d where d.member = :member and d.dutyDate >= :from")
    fun deleteAllByMemberAndDutyDateGreaterThanEqual(member: Member, from: LocalDate)

    @Modifying(flushAutomatically = true)
    @Query("delete from Duty d where d.dutyType = :dutyType and d.manualOverride = false and d.dutyDate >= :from")
    fun deleteAutomaticByDutyTypeAndDutyDateGreaterThanEqual(dutyType: DutyType, from: LocalDate)

    @Modifying(flushAutomatically = true)
    @Query("delete from Duty d where d.manualOverride = false and d.dutyDate >= :from")
    fun deleteAutomaticByDutyDateGreaterThanEqual(from: LocalDate)

    @EntityGraph(attributePaths = ["dutyType"])
    fun findByDutyDateAndMemberIn(dutyDate: LocalDate, members: List<Member>): List<Duty>

    fun deleteAllByDutyTypeIn(dutyTypes: List<DutyType>)

    fun deleteAllByTeamId(teamId: Long)

}
