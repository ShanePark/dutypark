package com.tistory.shanepark.dutypark.attachment.dto

import com.tistory.shanepark.dutypark.attachment.domain.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.domain.AttachmentUploadSession
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.Instant

class CreateSessionResponseTest {

    @Test
    fun `should map AttachmentUploadSession to CreateSessionResponse correctly`() {
        val expiresAt = Instant.now().plusSeconds(86400)
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.SCHEDULE,
            targetContextId = "schedule-123",
            ownerId = 1L,
            expiresAt = expiresAt
        )

        val response = CreateSessionResponse.from(session)

        assertThat(response.sessionId).isEqualTo(session.id)
        assertThat(response.expiresAt).isEqualTo(expiresAt)
        assertThat(response.contextType).isEqualTo(AttachmentContextType.SCHEDULE)
    }

    @Test
    fun `should handle null targetContextId`() {
        val expiresAt = Instant.now().plusSeconds(86400)
        val session = AttachmentUploadSession(
            contextType = AttachmentContextType.PROFILE,
            targetContextId = null,
            ownerId = 2L,
            expiresAt = expiresAt
        )

        val response = CreateSessionResponse.from(session)

        assertThat(response.sessionId).isEqualTo(session.id)
        assertThat(response.contextType).isEqualTo(AttachmentContextType.PROFILE)
    }
}
