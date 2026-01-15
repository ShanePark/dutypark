package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.LocalDateTime
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class SchedulePermissionServiceTest {

    private val scheduleRepository: ScheduleRepository = mock()
    private val friendService: FriendService = mock()
    private val memberService: MemberService = mock()

    private lateinit var service: SchedulePermissionService

    @BeforeEach
    fun setUp() {
        service = SchedulePermissionService(
            scheduleRepository = scheduleRepository,
            friendService = friendService,
            memberService = memberService
        )
    }

    @Test
    fun `write authority passes for owner`() {
        val member = memberWithId(1L)
        val loginMember = LoginMember(id = 1L, name = "owner")

        service.checkScheduleWriteAuthority(loginMember, member)
    }

    @Test
    fun `write authority passes for manager`() {
        val member = memberWithId(2L)
        val loginMember = LoginMember(id = 1L, name = "manager")
        whenever(memberService.isManager(eq(loginMember), eq(member))).thenReturn(true)

        service.checkScheduleWriteAuthority(loginMember, member)
    }

    @Test
    fun `write authority throws for unauthorized member`() {
        val member = memberWithId(2L)
        val loginMember = LoginMember(id = 1L, name = "other")
        whenever(memberService.isManager(eq(loginMember), eq(member))).thenReturn(false)

        assertThrows<AuthException> {
            service.checkScheduleWriteAuthority(loginMember, member)
        }
    }

    @Test
    fun `write authority by schedule id checks repository`() {
        val member = memberWithId(2L)
        val schedule = scheduleWithId(member, Visibility.FRIENDS)
        val loginMember = LoginMember(id = 1L, name = "manager")
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(memberService.isManager(eq(loginMember), eq(member))).thenReturn(true)

        service.checkScheduleWriteAuthority(loginMember, schedule.id)
    }

    @Test
    fun `read authority throws when visibility not allowed`() {
        val member = memberWithId(2L)
        val schedule = scheduleWithId(member, Visibility.PRIVATE)
        val loginMember = LoginMember(id = 1L, name = "viewer")
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(friendService.availableScheduleVisibilities(eq(loginMember), eq(member))).thenReturn(setOf(Visibility.PUBLIC))

        assertThrows<AuthException> {
            service.checkScheduleReadAuthority(loginMember, schedule.id)
        }
    }

    @Test
    fun `read authority passes when visibility allowed`() {
        val member = memberWithId(2L)
        val schedule = scheduleWithId(member, Visibility.FRIENDS)
        val loginMember = LoginMember(id = 1L, name = "viewer")
        whenever(scheduleRepository.findById(schedule.id)).thenReturn(Optional.of(schedule))
        whenever(friendService.availableScheduleVisibilities(eq(loginMember), eq(member))).thenReturn(
            setOf(Visibility.FRIENDS, Visibility.PUBLIC)
        )

        service.checkScheduleReadAuthority(loginMember, schedule.id)

        verify(friendService).checkVisibility(eq(loginMember), eq(member), eq(true))
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }

    private fun scheduleWithId(member: Member, visibility: Visibility): Schedule {
        val schedule = Schedule(
            member = member,
            content = "content",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now().plusHours(1),
            visibility = visibility
        )
        return schedule
    }
}
