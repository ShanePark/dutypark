package com.tistory.shanepark.dutypark.schedule.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime
import java.util.*

interface ScheduleRepository : JpaRepository<Schedule, UUID> {

    @Query(
        "SELECT s FROM Schedule s WHERE s.member = :member AND (" +
                "(s.startDateTime < :start AND s.endDateTime BETWEEN :start AND :end) OR " +
                "(s.startDateTime BETWEEN :start AND :end) OR " +
                "(s.startDateTime BETWEEN :start AND :end AND s.endDateTime > :end) OR " +
                "(s.startDateTime < :start AND s.endDateTime > :end)" +
                ")"
    )
    fun findSchedulesOfMonth(member: Member, start: LocalDateTime, end: LocalDateTime): List<Schedule>

    @Query("SELECT COALESCE(MAX(s.position), -1) FROM Schedule s WHERE s.member = :member AND s.startDateTime = :startDateTime")
    fun findMaxPosition(member: Member, startDateTime: LocalDateTime): Int

}

