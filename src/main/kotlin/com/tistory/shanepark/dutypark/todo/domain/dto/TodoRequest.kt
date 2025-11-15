package com.tistory.shanepark.dutypark.todo.domain.dto

import jakarta.validation.constraints.NotBlank
import org.hibernate.validator.constraints.Length
import org.springframework.validation.annotation.Validated
import java.util.UUID

@Validated
data class TodoRequest(

    @field: NotBlank
    @field: Length(min = 1, max = 100)
    val title: String,

    val content: String,
    val attachmentSessionId: UUID? = null,
    val orderedAttachmentIds: List<UUID> = emptyList()
)
