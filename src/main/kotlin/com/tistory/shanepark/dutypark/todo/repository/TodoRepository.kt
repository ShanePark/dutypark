package com.tistory.shanepark.dutypark.todo.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.time.LocalDate
import java.util.*

interface TodoRepository : JpaRepository<Todo, UUID> {

    fun countByMemberId(memberId: Long): Long

    fun countByMemberIdAndStatus(memberId: Long, status: TodoStatus): Long

    fun countByMemberIdAndStatusNotAndDueDateBefore(memberId: Long, status: TodoStatus, dueDate: LocalDate): Long

    fun countByMemberIdAndStatusNotAndDueDate(memberId: Long, status: TodoStatus, dueDate: LocalDate): Long

    @Query(
        "SELECT COALESCE(MIN(t.position), 0) " +
                "FROM Todo t " +
                "WHERE t.member = :member " +
                "AND t.status = :status"
    )
    fun findMinPositionByMemberAndStatus(
        @Param("member") member: Member,
        @Param("status") status: TodoStatus
    ): Int

    @Query(
        "SELECT COALESCE(MAX(t.position), -1) " +
                "FROM Todo t " +
                "WHERE t.member = :member " +
                "AND t.status = :status"
    )
    fun findMaxPositionByMemberAndStatus(
        @Param("member") member: Member,
        @Param("status") status: TodoStatus
    ): Int

    fun findAllByMemberAndStatusOrderByPosition(member: Member, status: TodoStatus): List<Todo>

    fun findAllByMemberAndStatusOrderByPositionAsc(member: Member, status: TodoStatus): List<Todo>

    fun findAllByMemberAndStatusOrderByCompletedDateDesc(member: Member, status: TodoStatus): List<Todo>

    fun findAllByMemberOrderByStatusAscPositionAsc(member: Member): List<Todo>

    fun findAllByMemberAndDueDateBetweenOrderByDueDateAsc(
        member: Member,
        startDate: LocalDate,
        endDate: LocalDate
    ): List<Todo>

    fun findAllByMemberAndDueDateOrderByPositionAsc(
        member: Member,
        dueDate: LocalDate
    ): List<Todo>

    fun findAllByMemberAndDueDateLessThanAndStatusNot(
        member: Member,
        dueDate: LocalDate,
        status: TodoStatus
    ): List<Todo>

    @Query(
        """
        SELECT DISTINCT t
        FROM Todo t
        JOIN FETCH t.member owner
        LEFT JOIN FETCH t.tags tag
        LEFT JOIN FETCH tag.member
        WHERE t.id IN (
            SELECT DISTINCT accessible.id
            FROM Todo accessible
            LEFT JOIN accessible.tags accessTag
            WHERE accessible.member = :member
               OR accessTag.member = :member
        )
        """
    )
    fun findAccessibleTodos(
        @Param("member") member: Member
    ): List<Todo>

    @Query(
        """
        SELECT DISTINCT t
        FROM Todo t
        JOIN FETCH t.member owner
        LEFT JOIN FETCH t.tags tag
        LEFT JOIN FETCH tag.member
        WHERE t.id IN (
            SELECT DISTINCT accessible.id
            FROM Todo accessible
            LEFT JOIN accessible.tags accessTag
            WHERE (accessible.member = :member OR accessTag.member = :member)
              AND accessible.status = :status
        )
        """
    )
    fun findAccessibleTodosByStatus(
        @Param("member") member: Member,
        @Param("status") status: TodoStatus
    ): List<Todo>

    @Query(
        """
        SELECT DISTINCT t
        FROM Todo t
        JOIN FETCH t.member owner
        LEFT JOIN FETCH t.tags tag
        LEFT JOIN FETCH tag.member
        WHERE t.id IN (
            SELECT DISTINCT accessible.id
            FROM Todo accessible
            LEFT JOIN accessible.tags accessTag
            WHERE (accessible.member = :member OR accessTag.member = :member)
              AND accessible.dueDate BETWEEN :startDate AND :endDate
        )
        """
    )
    fun findAccessibleTodosByDueDateBetween(
        @Param("member") member: Member,
        @Param("startDate") startDate: LocalDate,
        @Param("endDate") endDate: LocalDate
    ): List<Todo>

    @Query(
        """
        SELECT DISTINCT t
        FROM Todo t
        JOIN FETCH t.member owner
        LEFT JOIN FETCH t.tags tag
        LEFT JOIN FETCH tag.member
        WHERE t.id IN (
            SELECT DISTINCT accessible.id
            FROM Todo accessible
            LEFT JOIN accessible.tags accessTag
            WHERE (accessible.member = :member OR accessTag.member = :member)
              AND accessible.dueDate = :dueDate
        )
        """
    )
    fun findAccessibleTodosByDueDate(
        @Param("member") member: Member,
        @Param("dueDate") dueDate: LocalDate
    ): List<Todo>

    @Query(
        """
        SELECT DISTINCT t
        FROM Todo t
        JOIN FETCH t.member owner
        LEFT JOIN FETCH t.tags tag
        LEFT JOIN FETCH tag.member
        WHERE t.id IN (
            SELECT DISTINCT accessible.id
            FROM Todo accessible
            LEFT JOIN accessible.tags accessTag
            WHERE (accessible.member = :member OR accessTag.member = :member)
              AND accessible.dueDate < :dueDate
              AND accessible.status <> :status
        )
        """
    )
    fun findAccessibleOverdueTodos(
        @Param("member") member: Member,
        @Param("dueDate") dueDate: LocalDate,
        @Param("status") status: TodoStatus
    ): List<Todo>

    fun existsByIdAndMemberId(id: UUID, memberId: Long): Boolean

    @Query(
        """
        SELECT CASE WHEN COUNT(DISTINCT t) > 0 THEN true ELSE false END
        FROM Todo t
        LEFT JOIN t.tags tag
        WHERE t.id = :todoId
          AND (t.member.id = :memberId OR tag.member.id = :memberId)
        """
    )
    fun existsAccessibleTodo(
        @Param("todoId") todoId: UUID,
        @Param("memberId") memberId: Long
    ): Boolean

}
