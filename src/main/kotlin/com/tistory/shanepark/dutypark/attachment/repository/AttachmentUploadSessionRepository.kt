package com.tistory.shanepark.dutypark.attachment.repository

import com.tistory.shanepark.dutypark.attachment.domain.AttachmentUploadSession
import org.springframework.data.jpa.repository.JpaRepository
import java.time.Instant
import java.util.UUID

interface AttachmentUploadSessionRepository : JpaRepository<AttachmentUploadSession, UUID> {

    fun findAllByExpiresAtBefore(instant: Instant): List<AttachmentUploadSession>
}
