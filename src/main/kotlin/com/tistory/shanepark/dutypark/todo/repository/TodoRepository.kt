package com.tistory.shanepark.dutypark.todo.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.*

interface TodoRepository : JpaRepository<Todo, UUID> {

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

    fun findAllByMemberAndStatusOrderByPosition(member: Member, status: TodoStatus): List<Todo>

    fun findAllByMemberAndStatusOrderByCompletedDateDesc(member: Member, status: TodoStatus): List<Todo>

}
