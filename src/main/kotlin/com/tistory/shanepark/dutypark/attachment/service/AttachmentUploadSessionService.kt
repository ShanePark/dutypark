package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentUploadSessionRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import java.time.Clock
import java.util.*

@Service
class AttachmentUploadSessionService(
    private val sessionRepository: AttachmentUploadSessionRepository,
    private val permissionEvaluator: AttachmentPermissionEvaluator,
    private val clock: Clock
) {

    fun createSession(
        loginMember: LoginMember,
        contextType: AttachmentContextType,
        targetContextId: String?
    ): AttachmentUploadSession {
        val now = clock.instant()
        val expiresAt = now.plusSeconds(SESSION_LIFETIME_SECONDS)

        val session = AttachmentUploadSession(
            contextType = contextType,
            targetContextId = targetContextId,
            ownerId = loginMember.id,
            expiresAt = expiresAt
        )

        permissionEvaluator.checkSessionWritePermission(loginMember, session)

        return sessionRepository.save(session)
    }

    fun findById(sessionId: UUID): AttachmentUploadSession? {
        return sessionRepository.findById(sessionId).orElse(null)
    }

    fun deleteSession(sessionId: UUID) {
        sessionRepository.deleteById(sessionId)
    }

    companion object {
        private const val SESSION_LIFETIME_SECONDS = 24L * 60 * 60
    }
}
