package com.tistory.shanepark.dutypark.todo.domain.dto

import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import org.springframework.validation.annotation.Validated
import java.time.LocalDate
import java.util.UUID

@Validated
data class TodoRequest(

    @field: NotBlank
    @field: Length(min = 1, max = 50)
    val title: String,

    val content: String,
    val dueDate: LocalDate? = null,
    val attachmentSessionId: UUID? = null,
    val orderedAttachmentIds: List<UUID> = emptyList()
)
