package com.tistory.shanepark.dutypark.todo.repository

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import org.springframework.data.jpa.repository.JpaRepository
import org.springframework.data.jpa.repository.Query
import org.springframework.data.repository.query.Param
import java.util.*

interface TodoRepository : JpaRepository<Todo, UUID> {

    @Query(
        "SELECT COALESCE(MAX(t.position), 0) " +
                "FROM Todo t " +
                "WHERE t.member = :member"
    )
    fun findMaxPositionByMember(@Param("member") member: Member): Int

    fun findAllByMemberOrderByPosition(member: Member): List<Todo>

}
