package com.tistory.shanepark.dutypark.member.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.dto.DDaySaveDto
import com.tistory.shanepark.dutypark.member.repository.*
import com.tistory.shanepark.dutypark.member.block.service.BlockService
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.service.TodoService
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.mockito.kotlin.*
import org.slf4j.LoggerFactory
import org.springframework.context.ApplicationEventPublisher
import org.springframework.test.util.ReflectionTestUtils
import org.springframework.transaction.support.TransactionSynchronizationManager
import java.time.LocalDate
import java.util.Optional

class SocialMutationAuditLogTest {
    private val member = Member(name = "Actor", email = "secret@example.com").apply {
        ReflectionTestUtils.setField(this, "id", 10L)
    }
    private val login = LoginMember(id = 10, name = "Actor", isImpersonating = true, originalMemberId = 2)
    private val members = mock<MemberRepository>()

    private fun capture(type: Class<*>, block: (ListAppender<ILoggingEvent>) -> Unit) {
        val logger = LoggerFactory.getLogger(type) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try { block(appender) } finally { logger.detachAppender(appender); appender.stop() }
    }

    @Test
    fun `consent records policy and version only after commit without request fingerprint`() {
        val service = ConsentService(mock())
        capture(ConsentService::class.java) { logs ->
            TransactionSynchronizationManager.initSynchronization()
            try {
                service.recordConsent(member, PolicyType.TERMS, "v1", "192.0.2.1", "private-agent")
                assertThat(logs.list).isEmpty()
                val callbacks = TransactionSynchronizationManager.getSynchronizations()
                assertThat(callbacks).isNotEmpty()
                callbacks.forEach { it.afterCommit() }
                assertThat(logs.list.single().formattedMessage).contains("consent.recorded", "TERMS", "v1", "\"id\":10")
                    .doesNotContain("secret@example.com", "192.0.2.1", "private-agent")
            } finally { TransactionSynchronizationManager.clearSynchronization() }
        }
    }

    @Test
    fun `dday creation logs safe metadata without title`() {
        whenever(members.findById(10)).thenReturn(Optional.of(member))
        val days = mock<DDayRepository>()
        whenever(days.save(any<com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent>())).thenAnswer { invocation ->
            invocation.getArgument<com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent>(0).apply {
                ReflectionTestUtils.setField(this, "id", 30L)
            }
        }
        val service = DDayService(members, days, mock(), mock<PublicContentService>())
        capture(DDayService::class.java) { logs ->
            service.createDDay(login, DDaySaveDto(title = "private-title", date = LocalDate.of(2026, 10, 1), isPrivate = true))
            assertThat(logs.list.single().formattedMessage).contains("dday.created", "2026-10-01", "\"originalMemberId\":2")
                .doesNotContain("private-title", "secret@example.com")
        }
    }

    @Test
    fun `friend request cancellation records request kind target and actor`() {
        val target = Member(name = "Target").apply { ReflectionTestUtils.setField(this, "id", 20L) }
        whenever(members.findById(10)).thenReturn(Optional.of(member))
        whenever(members.findById(20)).thenReturn(Optional.of(target))
        val requests = mock<FriendRequestRepository>()
        whenever(requests.findAllByFromMemberAndToMemberAndStatus(any(), any(), any()))
            .thenReturn(listOf(FriendRequest(member, target)))
        val service = FriendService(mock(), requests, mock(), members, mock(), mock())
        capture(FriendService::class.java) { logs ->
            service.cancelFriendRequest(login, 20)
            assertThat(logs.list.single().formattedMessage).contains("friend_request.cancelled", "FRIEND_REQUEST", "\"toMemberId\":20", "\"originalMemberId\":2")
        }
    }

    @Test
    fun `blocking records newly created relation and suppresses duplicate block`() {
        val target = Member(name = "Target").apply { ReflectionTestUtils.setField(this, "id", 20L) }
        whenever(members.findMemberWithTeamForUpdate(10)).thenReturn(Optional.of(member))
        whenever(members.findMemberWithTeamForUpdate(20)).thenReturn(Optional.of(target))
        val blocks = mock<MemberBlockRepository>()
        val service = BlockService(blocks, members, mock(), mock(), mock<ScheduleRepository>(), mock<TodoRepository>())
        capture(BlockService::class.java) { logs ->
            service.block(10, 20)
            assertThat(logs.list.single().formattedMessage).contains("member.blocked", "\"blockedMemberId\":20")
            logs.list.clear()
            whenever(blocks.existsByBlockerIdAndBlockedId(10, 20)).thenReturn(true)
            service.block(10, 20)
            assertThat(logs.list).isEmpty()
        }
    }

    @Test
    fun `todo status records actual transition and suppresses repeated completion`() {
        whenever(members.findById(10)).thenReturn(Optional.of(member))
        val todos = mock<TodoRepository>()
        val todo = Todo(member = member, title = "private-title", content = "private-body", position = 0)
        whenever(todos.findByIdForUpdate(todo.id)).thenReturn(Optional.of(todo))
        whenever(todos.findMinTagOrderByMemberAndStatus(any(), any())).thenReturn(null)
        val service = TodoService(members, todos, mock<AttachmentRepository>(), mock<AttachmentService>(), mock(), mock<ApplicationEventPublisher>())
        capture(TodoService::class.java) { logs ->
            service.completeTodo(login, todo.id)
            assertThat(logs.list.single().formattedMessage).contains("todo.status_changed", "TODO", "DONE", "\"originalMemberId\":2")
                .doesNotContain("private-title", "private-body")
            logs.list.clear()
            service.completeTodo(login, todo.id)
            assertThat(logs.list).isEmpty()
        }
    }
    @Test
    fun `unblock records affected rows and keeps absent block silent`() {
        val blocks = mock<MemberBlockRepository>()
        val service = BlockService(blocks, members, mock(), mock(), mock(), mock())
        capture(BlockService::class.java) { logs ->
            service.unblock(10, 20)
            assertThat(logs.list).isEmpty()
            whenever(blocks.deleteByBlockerIdAndBlockedId(10, 20)).thenReturn(1L)
            service.unblock(10, 20, login.toAuditActor())
            assertThat(logs.list.single().formattedMessage).contains("member.unblocked", "\"deletedCount\":1", "\"originalMemberId\":2")
        }
    }

    @Test
    fun `dday update records only safe changes and suppresses no-op`() {
        val day = com.tistory.shanepark.dutypark.member.domain.entity.DDayEvent(
            member, "private-title", LocalDate.of(2026, 10, 1), true,
        ).apply { ReflectionTestUtils.setField(this, "id", 30L) }
        val days = mock<DDayRepository>()
        whenever(days.findById(30)).thenReturn(Optional.of(day))
        val service = DDayService(members, days, mock(), mock<PublicContentService>())
        capture(DDayService::class.java) { logs ->
            service.updateDDay(login, DDaySaveDto(30, "private-title", day.date, true))
            assertThat(logs.list).isEmpty()
            service.updateDDay(login, DDaySaveDto(30, "new-private-title", day.date.plusDays(1), true))
            assertThat(logs.list.single().formattedMessage).contains("dday.updated", "titleChanged", "2026-10-01", "2026-10-02")
                .doesNotContain("private-title", "new-private-title", "isPrivate")
        }
    }

    @Test
    fun `todo edit records text change indicators without content and suppresses no-op`() {
        whenever(members.findById(10)).thenReturn(Optional.of(member))
        val todos = mock<TodoRepository>()
        val todo = Todo(member, "private-title", "private-body", 0)
        whenever(todos.findById(todo.id)).thenReturn(Optional.of(todo))
        val service = TodoService(members, todos, mock(), mock(), mock(), mock())
        capture(TodoService::class.java) { logs ->
            service.editTodo(login, todo.id, todo.title, todo.content)
            assertThat(logs.list).isEmpty()
            service.editTodo(login, todo.id, "new-private-title", "new-private-body")
            assertThat(logs.list.single().formattedMessage).contains("todo.updated", "titleChanged", "contentChanged")
                .doesNotContain("private-title", "private-body")
        }
    }

}
