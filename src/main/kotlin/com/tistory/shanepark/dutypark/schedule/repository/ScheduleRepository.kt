package com.tistory.shanepark.dutypark.schedule.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDateTime
import java.util.*

interface ScheduleRepository : JpaRepository<Schedule, UUID> {

    @Query(
        "SELECT distinct s" +
                " FROM Schedule s" +
                " JOIN FETCH s.member m" +
                " LEFT JOIN FETCH s.tags t" +
                " LEFT JOIN FETCH t.member tm" +
                " WHERE (m = :member or tm = :member)" +
                " AND s.content LIKE %:content%" +
                " AND s.visibility IN (:visibility)" +
                " ORDER BY s.startDateTime DESC"
    )
    fun findByMemberAndContentContainingAndVisibilityIn(
        member: Member,
        content: String,
        visibility: Collection<Visibility>,
        pageable: Pageable,
    ): Page<Schedule>

    @Query(
        "SELECT s" +
                " FROM Schedule s" +
                " JOIN FETCH s.member m" +
                " LEFT JOIN FETCH s.tags t" +
                " LEFT JOIN FETCH t.member tm" +
                " WHERE m = :member " +
                " AND (" +
                "(s.startDateTime < :start AND s.endDateTime BETWEEN :start AND :end) OR " +
                "(s.startDateTime BETWEEN :start AND :end) OR " +
                "(s.startDateTime BETWEEN :start AND :end AND s.endDateTime > :end) OR " +
                "(s.startDateTime < :start AND s.endDateTime > :end)" +
                ")" +
                " AND s.visibility IN (:visibilities)"
    )
    fun findSchedulesOfMonth(
        member: Member,
        start: LocalDateTime,
        end: LocalDateTime,
        visibilities: Collection<Visibility>
    ): List<Schedule>

    @Query(
        "SELECT COALESCE(MAX(s.position), -1)" +
                " FROM Schedule s" +
                " WHERE s.member = :member AND YEAR(s.startDateTime) = YEAR(:startDateTime) AND MONTH(s.startDateTime) = MONTH(:startDateTime) AND DAY(s.startDateTime) = DAY(:startDateTime)"
    )
    fun findMaxPosition(member: Member, startDateTime: LocalDateTime): Int

    @Query(
        "SELECT s FROM Schedule s" +
                " JOIN FETCH s.member m" +
                " JOIN FETCH s.tags t" +
                " JOIN FETCH t.member tm" +
                " WHERE tm = :member AND (" +
                "(s.startDateTime < :start AND s.endDateTime BETWEEN :start AND :end) OR " +
                "(s.startDateTime BETWEEN :start AND :end) OR " +
                "(s.startDateTime BETWEEN :start AND :end AND s.endDateTime > :end) OR " +
                "(s.startDateTime < :start AND s.endDateTime > :end)" +
                ")" +
                "AND s.visibility IN (:visibilities)"
    )
    fun findTaggedSchedulesOfRange(
        member: Member,
        start: LocalDateTime,
        end: LocalDateTime,
        visibilities: Collection<Visibility>
    ): List<Schedule>


    @Query(
        "SELECT s FROM Schedule s" +
                " JOIN FETCH s.member m" +
                " LEFT JOIN FETCH s.tags t" +
                " LEFT JOIN FETCH t.member tm" +
                " WHERE m = :member" +
                " AND (s.startDateTime BETWEEN :startOfDay AND :endOfDay" +
                " OR s.endDateTime BETWEEN :startOfDay AND :endOfDay" +
                " OR (s.startDateTime <= :startOfDay AND s.endDateTime >= :endOfDay))"
    )
    fun findTodaySchedulesByMember(
        member: Member,
        @Param("startOfDay") startOfDay: LocalDateTime = LocalDateTime.now().toLocalDate().atStartOfDay(),
        @Param("endOfDay") endOfDay: LocalDateTime = LocalDateTime.now().toLocalDate().atTime(23, 59, 59)
    ): List<Schedule>

}

