package com.tistory.shanepark.dutypark.schedule.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import java.time.LocalDateTime
import java.util.*

interface ScheduleRepository : JpaRepository<Schedule, UUID> {

    @Query(
        value = """
        SELECT DISTINCT s
        FROM Schedule s
        JOIN FETCH s.member m
        LEFT JOIN FETCH s.tags t
        LEFT JOIN FETCH t.member tm
        WHERE (m = :member OR tm = :member)
        AND s.content LIKE %:content%
        AND s.visibility IN (:visibility)
        ORDER BY s.startDateTime DESC
    """,
        countQuery = """
        SELECT COUNT(DISTINCT s)
        FROM Schedule s
        JOIN s.member m
        LEFT JOIN s.tags t
        LEFT JOIN t.member tm
        WHERE (m = :member OR tm = :member)
        AND s.content LIKE %:content%
        AND s.visibility IN (:visibility)
    """
    )
    fun findByMemberAndContentContainingAndVisibilityIn(
        member: Member,
        content: String,
        visibility: Collection<Visibility>,
        pageable: Pageable
    ): Page<Schedule>

    @Query(
        "SELECT s" +
                " FROM Schedule s" +
                " JOIN FETCH s.member m" +
                " LEFT JOIN FETCH s.tags t" +
                " LEFT JOIN FETCH t.member tm" +
                " WHERE m = :member " +
                " AND s.startDateTime <= :end AND s.endDateTime >= :start" +
                " AND s.visibility IN (:visibilities)"
    )
    fun findSchedulesOfMemberRangeIn(
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
        """
    SELECT DISTINCT s
    FROM Schedule s
    JOIN FETCH s.member m
    LEFT JOIN FETCH s.tags t
    LEFT JOIN FETCH t.member tm
    WHERE s IN (
        SELECT s2
        FROM Schedule s2
        JOIN s2.tags t2
        WHERE t2.member = :taggedMember
        AND s2.startDateTime <= :end
        AND s2.endDateTime >= :start
        AND s2.visibility IN :visibilities
    )   
    """
    )
    fun findTaggedSchedulesOfRange(
        taggedMember: Member,
        start: LocalDateTime,
        end: LocalDateTime,
        visibilities: Collection<Visibility>
    ): List<Schedule>

    fun findAllByParsingTimeStatus(parsingTimeStatus: ParsingTimeStatus): List<Schedule>

}

