package com.tistory.shanepark.dutypark.todo.domain.dto

import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import org.springframework.validation.annotation.Validated

@Validated
data class TodoRequest(

    @field: NotBlank
    @field: Length(min = 1, max = 100)
    val title: String,

    val content: String
)
