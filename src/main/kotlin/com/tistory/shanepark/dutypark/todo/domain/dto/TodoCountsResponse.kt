package com.tistory.shanepark.dutypark.todo.domain.dto

data class TodoCountsResponse(
    val todo: Int,
    val inProgress: Int,
    val done: Int,
    val total: Int
)
