package com.tistory.shanepark.dutypark.admin.service

import ch.qos.logback.classic.Logger
import ch.qos.logback.classic.spi.ILoggingEvent
import ch.qos.logback.core.read.ListAppender
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import java.util.Optional
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.slf4j.LoggerFactory

class AdminServiceSuspensionTest {

    private val memberRepository: MemberRepository = mock()
    private val refreshTokenRepository: RefreshTokenRepository = mock()
    private val scheduleRepository: ScheduleRepository = mock()
    private val todoRepository: TodoRepository = mock()
    private val friendRelationRepository: FriendRelationRepository = mock()
    private val friendRequestRepository: FriendRequestRepository = mock()
    private val memberManagerRepository: MemberManagerRepository = mock()
    private val dDayRepository: DDayRepository = mock()
    private val notificationRepository: NotificationRepository = mock()
    private val memberSocialAccountService: MemberSocialAccountService = mock()
    private val refreshTokenService: RefreshTokenService = mock()
    private val dutyparkProperties: DutyparkProperties = mock()

    private lateinit var service: AdminService

    @BeforeEach
    fun setUp() {
        service = AdminService(
            memberRepository = memberRepository,
            refreshTokenRepository = refreshTokenRepository,
            scheduleRepository = scheduleRepository,
            todoRepository = todoRepository,
            friendRelationRepository = friendRelationRepository,
            friendRequestRepository = friendRequestRepository,
            memberManagerRepository = memberManagerRepository,
            dDayRepository = dDayRepository,
            notificationRepository = notificationRepository,
            memberSocialAccountService = memberSocialAccountService,
            refreshTokenService = refreshTokenService,
            dutyparkProperties = dutyparkProperties,
        )
    }

    @Test
    fun `member status audit includes admin and target only for actual transitions`() {
        val member = Member(name = "member", email = "private@example.test")
        val actor = LoginMember(id = 99L, name = "Admin Actor", isAdmin = true)
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        val logger = LoggerFactory.getLogger(AdminService::class.java) as Logger
        val appender = ListAppender<ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            service.suspendMember(1L, actor)
            service.suspendMember(1L, actor)
            service.reinstateMember(1L)
            service.reinstateMember(1L)
            val messages = appender.list.map { it.formattedMessage }
            assertThat(messages).hasSize(2)
            assertThat(messages[0]).contains("member.suspended", "\"id\":99", "\"memberId\":1", "ACTIVE", "SUSPENDED")
            assertThat(messages[1]).contains("member.reinstated", "SUSPENDED", "ACTIVE")
            assertThat(messages.joinToString()).doesNotContain("private@example.test")
        } finally {
            logger.detachAppender(appender)
        }
    }

    @Test
    fun `suspend obtains a member write lock before changing status`() {
        val member = Member(name = "Suspended Member")
        val actor = LoginMember(id = 99L, name = "Admin Actor", isAdmin = true)
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))

        service.suspendMember(1L, actor)

        verify(memberRepository).findMemberWithTeamForUpdate(1L)
        verify(memberRepository, never()).findById(1L)
        verify(refreshTokenService).revokeAllRefreshTokensByMember(member, actor, "account_suspension")
    }

    @Test
    fun `reinstate obtains a member write lock before changing status`() {
        val member = Member(name = "member").also { it.suspend() }
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))

        service.reinstateMember(1L)

        verify(memberRepository).findMemberWithTeamForUpdate(1L)
        verify(memberRepository, never()).findById(1L)
    }
}
