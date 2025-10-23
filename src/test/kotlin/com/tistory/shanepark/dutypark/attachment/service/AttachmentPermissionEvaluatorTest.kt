package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.schedule.service.SchedulePermissionService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import java.time.Instant
import java.util.*

class AttachmentPermissionEvaluatorTest {

    private lateinit var evaluator: AttachmentPermissionEvaluator
    private lateinit var schedulePermissionService: SchedulePermissionService

    private val loginMember = LoginMember(id = 1L, name = "user1")
    private val otherMember = LoginMember(id = 2L, name = "user2")

    @BeforeEach
    fun setUp() {
        schedulePermissionService = mock()
        evaluator = AttachmentPermissionEvaluator(schedulePermissionService)
    }

    @Test
    fun `checkReadPermission delegates to scheduleService for schedule attachments`() {
        val attachment = createAttachment(contextType = AttachmentContextType.SCHEDULE, contextId = UUID.randomUUID().toString())

        evaluator.checkReadPermission(loginMember, attachment)

        org.mockito.kotlin.verify(schedulePermissionService).checkScheduleReadAuthority(
            org.mockito.kotlin.eq(loginMember),
            org.mockito.kotlin.any()
        )
    }

    @Test
    fun `checkReadPermission throws when attachment has no contextId`() {
        val attachment = createAttachment(contextType = AttachmentContextType.SCHEDULE, contextId = null)

        assertThatThrownBy {
            evaluator.checkReadPermission(loginMember, attachment)
        }.isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("has no contextId")
    }

    @Test
    fun `checkWritePermission throws when attachment has no contextId`() {
        val attachment = createAttachment(contextType = AttachmentContextType.SCHEDULE, contextId = null)

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(IllegalStateException::class.java)
            .hasMessageContaining("has no contextId")
    }

    @Test
    fun `checkReadPermission throws UnsupportedOperationException for PROFILE context`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = "1")

        assertThatThrownBy {
            evaluator.checkReadPermission(loginMember, attachment)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("PROFILE not yet implemented")
    }

    @Test
    fun `checkReadPermission throws UnsupportedOperationException for TEAM context`() {
        val attachment = createAttachment(contextType = AttachmentContextType.TEAM, contextId = "1")

        assertThatThrownBy {
            evaluator.checkReadPermission(loginMember, attachment)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("TEAM not yet implemented")
    }

    @Test
    fun `checkReadPermission throws UnsupportedOperationException for TODO context`() {
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = "1")

        assertThatThrownBy {
            evaluator.checkReadPermission(loginMember, attachment)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("TODO not yet implemented")
    }

    @Test
    fun `checkWritePermission throws UnsupportedOperationException for PROFILE context`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = "1")

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("PROFILE not yet implemented")
    }

    @Test
    fun `checkWritePermission throws UnsupportedOperationException for TEAM context`() {
        val attachment = createAttachment(contextType = AttachmentContextType.TEAM, contextId = "1")

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("TEAM not yet implemented")
    }

    @Test
    fun `checkWritePermission throws UnsupportedOperationException for TODO context`() {
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = "1")

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("TODO not yet implemented")
    }

    @Test
    fun `checkSessionOwnership succeeds when session belongs to user`() {
        val session = createSession(ownerId = loginMember.id)

        evaluator.checkSessionOwnership(loginMember, session)
    }

    @Test
    fun `checkSessionOwnership throws when session does not belong to user`() {
        val session = createSession(ownerId = otherMember.id)

        assertThatThrownBy {
            evaluator.checkSessionOwnership(loginMember, session)
        }.isInstanceOf(AuthException::class.java)
            .hasMessageContaining("does not belong to user")
    }

    @Test
    fun `checkSessionWritePermission succeeds when session belongs to user and has no targetContextId`() {
        val session = createSession(ownerId = loginMember.id, targetContextId = null)

        evaluator.checkSessionWritePermission(loginMember, session)
    }

    @Test
    fun `checkSessionWritePermission throws when session does not belong to user`() {
        val session = createSession(ownerId = otherMember.id, targetContextId = null)

        assertThatThrownBy {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.isInstanceOf(AuthException::class.java)
            .hasMessageContaining("does not belong to user")
    }

    @Test
    fun `checkSessionWritePermission throws UnsupportedOperationException for PROFILE context with targetContextId`() {
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.PROFILE,
            targetContextId = "1"
        )

        assertThatThrownBy {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("PROFILE not yet implemented")
    }

    @Test
    fun `checkSessionWritePermission throws UnsupportedOperationException for TEAM context with targetContextId`() {
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.TEAM,
            targetContextId = "1"
        )

        assertThatThrownBy {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("TEAM not yet implemented")
    }

    @Test
    fun `checkSessionWritePermission throws UnsupportedOperationException for TODO context with targetContextId`() {
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.TODO,
            targetContextId = "1"
        )

        assertThatThrownBy {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.isInstanceOf(UnsupportedOperationException::class.java)
            .hasMessageContaining("TODO not yet implemented")
    }

    private fun createAttachment(
        contextType: AttachmentContextType,
        contextId: String?,
        uploadSessionId: UUID? = null,
        createdBy: Long = 1L
    ): Attachment {
        return Attachment(
            contextType = contextType,
            contextId = contextId,
            uploadSessionId = uploadSessionId,
            originalFilename = "test.jpg",
            storedFilename = "${UUID.randomUUID()}.jpg",
            contentType = "image/jpeg",
            size = 1024L,
            storagePath = "/tmp",
            createdBy = createdBy
        )
    }

    private fun createSession(
        ownerId: Long,
        contextType: AttachmentContextType = AttachmentContextType.SCHEDULE,
        targetContextId: String? = null
    ): AttachmentUploadSession {
        return AttachmentUploadSession(
            contextType = contextType,
            targetContextId = targetContextId,
            ownerId = ownerId,
            expiresAt = Instant.now().plusSeconds(3600)
        )
    }
}
