package com.tistory.shanepark.dutypark.todo.domain.dto

data class TodoBoardResponse(
    val todo: List<TodoResponse>,
    val inProgress: List<TodoResponse>,
    val done: List<TodoResponse>,
    val counts: TodoCountsResponse
)
