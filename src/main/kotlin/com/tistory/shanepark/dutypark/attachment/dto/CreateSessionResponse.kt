package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import java.time.Instant
import java.util.UUID

data class CreateSessionResponse(
    val sessionId: UUID,
    val expiresAt: Instant,
    val contextType: AttachmentContextType
) {
    companion object {
        fun from(session: AttachmentUploadSession): CreateSessionResponse {
            return CreateSessionResponse(
                sessionId = session.id!!,
                expiresAt = session.expiresAt,
                contextType = session.contextType
            )
        }
    }
}
