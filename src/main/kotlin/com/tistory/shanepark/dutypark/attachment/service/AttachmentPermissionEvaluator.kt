package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.schedule.service.SchedulePermissionService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.stereotype.Component
import java.util.*

@Component
class AttachmentPermissionEvaluator(
    private val schedulePermissionService: SchedulePermissionService,
    private val todoRepository: TodoRepository
) {
    fun checkReadPermission(loginMember: LoginMember?, attachment: Attachment) {
        when (attachment.contextType) {
            AttachmentContextType.SCHEDULE -> checkScheduleReadPermission(loginMember, attachment)
            AttachmentContextType.TODO -> checkTodoPermission(loginMember, attachment)
            AttachmentContextType.PROFILE -> { /* Public read - no auth required */ }
            AttachmentContextType.TEAM -> throw UnsupportedOperationException("Context type ${attachment.contextType} not yet implemented")
        }
    }

    fun checkWritePermission(loginMember: LoginMember, attachment: Attachment) {
        when (attachment.contextType) {
            AttachmentContextType.SCHEDULE -> checkScheduleWritePermission(loginMember, attachment)
            AttachmentContextType.TODO -> checkTodoPermission(loginMember, attachment)
            AttachmentContextType.PROFILE -> checkProfileWritePermission(loginMember, attachment)
            AttachmentContextType.TEAM -> throw UnsupportedOperationException("Context type ${attachment.contextType} not yet implemented")
        }
    }

    fun checkSessionOwnership(loginMember: LoginMember, session: AttachmentUploadSession) {
        if (session.ownerId != loginMember.id) {
            throw AuthException("Session ${session.id} does not belong to user ${loginMember.id}")
        }
    }

    fun checkSessionWritePermission(loginMember: LoginMember, session: AttachmentUploadSession) {
        checkSessionOwnership(loginMember, session)

        if (session.targetContextId != null) {
            when (session.contextType) {
                AttachmentContextType.SCHEDULE -> checkScheduleWritePermissionById(
                    loginMember,
                    UUID.fromString(session.targetContextId)
                )
                AttachmentContextType.TODO -> checkTodoSessionPermission(loginMember, session)
                AttachmentContextType.PROFILE -> checkProfileSessionPermission(loginMember, session)
                AttachmentContextType.TEAM -> throw UnsupportedOperationException("Context type ${session.contextType} not yet implemented")
            }
        }
    }

    private fun checkScheduleReadPermission(loginMember: LoginMember?, attachment: Attachment) {
        val contextId = attachment.contextId
            ?: throw IllegalStateException("Attachment ${attachment.id} has no contextId")

        checkScheduleReadPermissionById(loginMember, UUID.fromString(contextId))
    }

    private fun checkScheduleWritePermission(loginMember: LoginMember, attachment: Attachment) {
        val contextId = attachment.contextId
            ?: throw IllegalStateException("Attachment ${attachment.id} has no contextId")

        checkScheduleWritePermissionById(loginMember, UUID.fromString(contextId))
    }

    private fun checkScheduleReadPermissionById(loginMember: LoginMember?, scheduleId: UUID) {
        schedulePermissionService.checkScheduleReadAuthority(loginMember, scheduleId)
    }

    private fun checkScheduleWritePermissionById(loginMember: LoginMember, scheduleId: UUID) {
        schedulePermissionService.checkScheduleWriteAuthority(loginMember, scheduleId)
    }

    private fun checkTodoPermission(loginMember: LoginMember?, attachment: Attachment) {
        val contextId = attachment.contextId
            ?: throw IllegalStateException("Attachment ${attachment.id} has no contextId")

        val todoId = UUID.fromString(contextId)
        ensureTodoOwnership(loginMember, todoId)
    }

    private fun checkTodoSessionPermission(loginMember: LoginMember, session: AttachmentUploadSession) {
        val targetContextId = session.targetContextId
            ?: throw IllegalStateException("Session ${session.id} has no targetContextId for TODO context")

        val todoId = UUID.fromString(targetContextId)
        ensureTodoOwnership(loginMember, todoId)
    }

    private fun ensureTodoOwnership(loginMember: LoginMember?, todoId: UUID) {
        val requester = loginMember ?: throw AuthException("Login required to access todo")
        val todo = todoRepository.findById(todoId)
            .orElseThrow { IllegalArgumentException("Todo not found") }

        if (todo.member.id != requester.id) {
            throw AuthException("Todo $todoId does not belong to user ${requester.id}")
        }
    }

    private fun checkProfileWritePermission(loginMember: LoginMember, attachment: Attachment) {
        val contextId = attachment.contextId
            ?: throw IllegalStateException("Attachment ${attachment.id} has no contextId")

        if (contextId != loginMember.id.toString()) {
            throw AuthException("Profile photo does not belong to user ${loginMember.id}")
        }
    }

    private fun checkProfileSessionPermission(loginMember: LoginMember, session: AttachmentUploadSession) {
        val targetContextId = session.targetContextId
            ?: throw IllegalStateException("Session ${session.id} has no targetContextId for PROFILE context")

        if (targetContextId != loginMember.id.toString()) {
            throw AuthException("Profile session does not belong to user ${loginMember.id}")
        }
    }

}
