package com.tistory.shanepark.dutypark.todo.domain.dto

import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import java.time.LocalDate
import java.time.LocalDateTime

data class TodoResponse(
    val id: String,
    val title: String,
    val content: String,
    val position: Int?,
    val status: TodoStatus,
    val createdDate: LocalDateTime,
    val completedDate: LocalDateTime?,
    val dueDate: LocalDate?,
    val isOverdue: Boolean,
    val hasAttachments: Boolean = false
) {

    companion object {
        fun from(todoEntity: Todo, hasAttachments: Boolean = false): TodoResponse {
            val dueDate = todoEntity.dueDate
            val isOverdue = dueDate != null &&
                    dueDate < LocalDate.now() &&
                    todoEntity.status != TodoStatus.DONE

            return TodoResponse(
                id = todoEntity.id.toString(),
                title = todoEntity.title,
                content = todoEntity.content,
                position = todoEntity.position,
                status = todoEntity.status,
                createdDate = todoEntity.createdDate,
                completedDate = todoEntity.completedDate,
                dueDate = dueDate,
                isOverdue = isOverdue,
                hasAttachments = hasAttachments
            )
        }
    }

}
