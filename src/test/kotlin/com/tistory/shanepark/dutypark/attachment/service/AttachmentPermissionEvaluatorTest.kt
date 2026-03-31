package com.tistory.shanepark.dutypark.attachment.service

import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.entity.AttachmentUploadSession
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.service.SchedulePermissionService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.assertj.core.api.Assertions.assertThatCode
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.Instant
import java.util.*

class AttachmentPermissionEvaluatorTest {

    private lateinit var evaluator: AttachmentPermissionEvaluator
    private lateinit var schedulePermissionService: SchedulePermissionService
    private lateinit var todoRepository: TodoRepository

    private val loginMember = LoginMember(id = 1L, name = "user1")
    private val otherMember = LoginMember(id = 2L, name = "user2")

    @BeforeEach
    fun setUp() {
        schedulePermissionService = mock()
        todoRepository = mock()
        evaluator = AttachmentPermissionEvaluator(schedulePermissionService, todoRepository)
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
        }.isInstanceOf(BadRequestException::class.java)
            .hasMessage("attachment.context.missing")
    }

    @Test
    fun `checkWritePermission throws when attachment has no contextId`() {
        val attachment = createAttachment(contextType = AttachmentContextType.SCHEDULE, contextId = null)

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(BadRequestException::class.java)
            .hasMessage("attachment.context.missing")
    }

    @Test
    fun `checkReadPermission succeeds for PROFILE context without login (public)`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = "1")

        assertThatCode {
            evaluator.checkReadPermission(null, attachment)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkReadPermission succeeds for PROFILE context with login`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = "1")

        assertThatCode {
            evaluator.checkReadPermission(loginMember, attachment)
        }.doesNotThrowAnyException()
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
    fun `checkWritePermission succeeds for PROFILE context when owner`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = loginMember.id.toString())

        assertThatCode {
            evaluator.checkWritePermission(loginMember, attachment)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkWritePermission throws AuthException for PROFILE context when not owner`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = otherMember.id.toString())

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.profile.forbidden")
    }

    @Test
    fun `checkReadPermission succeeds for PROFILE context with null contextId - public access`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = null)

        assertThatCode {
            evaluator.checkReadPermission(loginMember, attachment)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkWritePermission throws for PROFILE context with null contextId`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = null)

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(BadRequestException::class.java)
            .hasMessage("attachment.context.missing")
    }

    @Test
    fun `checkWritePermission throws AuthException for PROFILE context when contextId does not match loginMember id`() {
        val attachment = createAttachment(contextType = AttachmentContextType.PROFILE, contextId = "999")

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.profile.forbidden")
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
            .hasMessage("attachment.session.forbidden")
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
            .hasMessage("attachment.session.forbidden")
    }

    @Test
    fun `checkSessionWritePermission succeeds for PROFILE context when owner`() {
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.PROFILE,
            targetContextId = loginMember.id.toString()
        )

        assertThatCode {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkSessionWritePermission throws AuthException for PROFILE context when not owner`() {
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.PROFILE,
            targetContextId = otherMember.id.toString()
        )

        assertThatThrownBy {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.profile.forbidden")
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
    fun `checkReadPermission succeeds for TODO context when owner`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsAccessibleTodo(todoId, loginMember.id)).thenReturn(true)

        assertThatCode {
            evaluator.checkReadPermission(loginMember, attachment)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkReadPermission succeeds for TODO context when tagged member`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsAccessibleTodo(todoId, loginMember.id)).thenReturn(true)

        assertThatCode {
            evaluator.checkReadPermission(loginMember, attachment)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkReadPermission throws AuthException for TODO context when not accessible`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsAccessibleTodo(todoId, loginMember.id)).thenReturn(false)

        assertThatThrownBy {
            evaluator.checkReadPermission(loginMember, attachment)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.todo.access.forbidden")
    }

    @Test
    fun `checkReadPermission throws AuthException when login is null for TODO context`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        assertThatThrownBy {
            evaluator.checkReadPermission(null, attachment)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.todo.auth.required")
    }

    @Test
    fun `checkReadPermission throws IllegalArgumentException when TODO not found`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        whenever(todoRepository.existsById(todoId)).thenReturn(false)

        assertThatThrownBy {
            evaluator.checkReadPermission(loginMember, attachment)
        }.isInstanceOf(IllegalArgumentException::class.java)
            .hasMessageContaining("Todo not found")
    }

    @Test
    fun `checkWritePermission succeeds for TODO context when owner`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsByIdAndMemberId(todoId, loginMember.id)).thenReturn(true)

        assertThatCode {
            evaluator.checkWritePermission(loginMember, attachment)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkWritePermission throws AuthException for TODO context when not owner`() {
        val todoId = UUID.randomUUID()
        val attachment = createAttachment(contextType = AttachmentContextType.TODO, contextId = todoId.toString())

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsByIdAndMemberId(todoId, loginMember.id)).thenReturn(false)

        assertThatThrownBy {
            evaluator.checkWritePermission(loginMember, attachment)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.todo.write.forbidden")
    }

    @Test
    fun `checkSessionWritePermission succeeds for TODO context when owner`() {
        val todoId = UUID.randomUUID()
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.TODO,
            targetContextId = todoId.toString()
        )

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsByIdAndMemberId(todoId, loginMember.id)).thenReturn(true)

        assertThatCode {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.doesNotThrowAnyException()
    }

    @Test
    fun `checkSessionWritePermission throws AuthException for TODO context when todo belongs to someone else`() {
        val todoId = UUID.randomUUID()
        val session = createSession(
            ownerId = loginMember.id,
            contextType = AttachmentContextType.TODO,
            targetContextId = todoId.toString()
        )

        whenever(todoRepository.existsById(todoId)).thenReturn(true)
        whenever(todoRepository.existsByIdAndMemberId(todoId, loginMember.id)).thenReturn(false)

        assertThatThrownBy {
            evaluator.checkSessionWritePermission(loginMember, session)
        }.isInstanceOf(AuthException::class.java)
            .hasMessage("attachment.todo.write.forbidden")
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

    private fun createMember(id: Long): Member {
        val member = Member(name = "user$id", password = "password")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }

    private fun createTodo(member: Member, todoId: UUID): Todo {
        val todo = Todo(
            member = member,
            title = "Test Todo",
            content = "Test Content",
            position = 1
        )
        ReflectionTestUtils.setField(todo, "id", todoId)
        return todo
    }
}
