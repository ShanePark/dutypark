package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.schedule.service.SchedulePermissionService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Component
import java.util.*

@Component
class AttachmentPermissionEvaluator(
    private val schedulePermissionService: SchedulePermissionService
) {
    fun checkReadPermission(loginMember: LoginMember?, attachment: Attachment) {
        when (attachment.contextType) {
            AttachmentContextType.SCHEDULE -> checkScheduleReadPermission(loginMember, attachment)
            AttachmentContextType.PROFILE,
            AttachmentContextType.TEAM,
            AttachmentContextType.TODO -> throw UnsupportedOperationException("Context type ${attachment.contextType} not yet implemented")
        }
    }

    fun checkWritePermission(loginMember: LoginMember, attachment: Attachment) {
        when (attachment.contextType) {
            AttachmentContextType.SCHEDULE -> checkScheduleWritePermission(loginMember, attachment)
            AttachmentContextType.PROFILE,
            AttachmentContextType.TEAM,
            AttachmentContextType.TODO -> throw UnsupportedOperationException("Context type ${attachment.contextType} not yet implemented")
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

                AttachmentContextType.PROFILE,
                AttachmentContextType.TEAM,
                AttachmentContextType.TODO -> throw UnsupportedOperationException("Context type ${session.contextType} not yet implemented")
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

}
