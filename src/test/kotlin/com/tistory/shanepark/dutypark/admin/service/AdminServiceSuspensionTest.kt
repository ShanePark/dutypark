package com.tistory.shanepark.dutypark.admin.service

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
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.util.Optional

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
    fun `suspend obtains a member write lock before changing status`() {
        val member = Member(name = "member")
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))

        service.suspendMember(1L)

        verify(memberRepository).findMemberWithTeamForUpdate(1L)
        verify(memberRepository, never()).findById(1L)
        verify(refreshTokenService).revokeAllRefreshTokensByMember(member)
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
