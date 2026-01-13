package com.tistory.shanepark.dutypark.todo.domain.dto

import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import java.util.*

data class TodoStatusChangeRequest(
    val status: TodoStatus,
    val orderedIds: List<UUID>
)
