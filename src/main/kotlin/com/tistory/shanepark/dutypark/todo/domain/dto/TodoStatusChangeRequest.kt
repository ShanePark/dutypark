package com.tistory.shanepark.dutypark.todo.domain.dto

import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus

data class TodoStatusChangeRequest(
    val status: TodoStatus,
    val position: Int? = null
)
