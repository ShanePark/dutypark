package com.tistory.shanepark.dutypark.todo.domain.dto

import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import java.time.LocalDateTime

data class TodoResponse(
    val id: String,
    val title: String,
    val content: String,
    val position: Int,
    val createdDate: LocalDateTime,
) {

    companion object {
        fun from(todoEntity: Todo): TodoResponse {
            return TodoResponse(
                id = todoEntity.id.toString(),
                title = todoEntity.title,
                content = todoEntity.content,
                position = todoEntity.position,
                createdDate = todoEntity.createdDate
            )
        }
    }

}
