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
        fun from(todo: Todo): TodoResponse {
            return TodoResponse(
                id = todo.id.toString(),
                title = todo.title,
                content = todo.content,
                position = todo.position,
                createdDate = todo.createdDate
            )
        }
    }

}
