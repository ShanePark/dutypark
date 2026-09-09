package com.tistory.shanepark.dutypark.todo.domain.dto

import java.util.UUID

data class TodoBulkDeleteRequest(
    val todoIds: List<UUID> = emptyList(),
)
