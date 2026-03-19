package com.tistory.shanepark.dutypark.todo.domain.dto

import com.tistory.shanepark.dutypark.member.domain.dto.MemberPreviewDto
import com.tistory.shanepark.dutypark.member.domain.dto.toMemberPreviewDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
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
    val isTagged: Boolean,
    val owner: String,
    val taggedByMember: MemberPreviewDto? = null,
    val tags: List<MemberPreviewDto> = listOf(),
    val hasAttachments: Boolean = false
) {

    companion object {
        fun from(
            todoEntity: Todo,
            viewer: Member,
            hasAttachments: Boolean = false
        ): TodoResponse {
            val dueDate = todoEntity.dueDate
            val isOverdue = dueDate != null &&
                    dueDate < LocalDate.now() &&
                    todoEntity.status != TodoStatus.DONE
            val isTagged = todoEntity.member.id != viewer.id

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
                isTagged = isTagged,
                owner = todoEntity.member.name,
                taggedByMember = todoEntity.member.takeIf { isTagged }?.toMemberPreviewDto(),
                tags = todoEntity.tags.map { it.member.toMemberPreviewDto() },
                hasAttachments = hasAttachments
            )
        }
    }

}
