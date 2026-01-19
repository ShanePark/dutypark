package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendDetail
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestType
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.whenever
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class DashboardServiceTest {

    private val fixedDate = LocalDate.of(2025, 1, 15)

    private val memberRepository: MemberRepository = mock()
    private val dutyRepository: DutyRepository = mock()
    private val scheduleRepository: ScheduleRepository = mock()
    private val friendRelationRepository: FriendRelationRepository = mock()
    private val friendService: FriendService = mock()

    private lateinit var dashboardService: DashboardService

    @BeforeEach
    fun setUp() {
        dashboardService = DashboardService(
            memberRepository = memberRepository,
            dutyRepository = dutyRepository,
            scheduleRepository = scheduleRepository,
            friendRelationRepository = friendRelationRepository,
            friendService = friendService
        )
    }

    @Test
    fun `my returns default duty and merges personal and tagged schedules`() {
        val team = Team("team")
        val member = memberWithId(1L, team)
        val loginMember = LoginMember(id = 1L, name = "user")
        whenever(memberRepository.findMemberWithTeam(1L)).thenReturn(Optional.of(member))
        whenever(friendService.availableScheduleVisibilities(eq(loginMember), eq(member))).thenReturn(
            setOf(Visibility.FRIENDS)
        )

        val today = fixedDate
        val personalSchedule = Schedule(
            member = member,
            content = "personal",
            startDateTime = today.atStartOfDay(),
            endDateTime = today.atTime(1, 0)
        )
        val taggedOwner = memberWithId(2L, team)
        val taggedSchedule = Schedule(
            member = taggedOwner,
            content = "tagged",
            startDateTime = today.atStartOfDay(),
            endDateTime = today.atTime(2, 0)
        )

        whenever(
            scheduleRepository.findSchedulesOfMemberRangeIn(eq(member), any(), any(), any())
        ).thenReturn(listOf(personalSchedule))
        whenever(
            scheduleRepository.findTaggedSchedulesOfRange(eq(member), any(), any(), any())
        ).thenReturn(listOf(taggedSchedule))
        whenever(dutyRepository.findByMemberAndDutyDate(member, today)).thenReturn(null)

        val result = dashboardService.my(loginMember)

        assertThat(result.duty?.dutyType).isEqualTo(team.defaultDutyName)
        assertThat(result.duty?.isOff).isTrue
        assertThat(result.schedules).hasSize(2)
        assertThat(result.schedules.count { it.isTagged }).isEqualTo(1)
    }

    @Test
    fun `friend returns sorted friends and pending requests`() {
        val team = Team("team")
        val member = memberWithId(1L, team)
        val friend1 = memberWithId(2L, team)
        val friend2 = memberWithId(3L, team)
        val loginMember = LoginMember(id = 1L, name = "user")

        whenever(memberRepository.findMemberWithTeam(1L)).thenReturn(Optional.of(member))
        whenever(friendService.buildScheduleVisibilityMap(eq(loginMember), any())).thenReturn(
            mapOf(
                friend1.id!! to Visibility.friends(),
                friend2.id!! to Visibility.friends()
            )
        )
        whenever(scheduleRepository.findSchedulesOfMembersRangeIn(any(), any(), any(), any())).thenReturn(emptyList())
        whenever(scheduleRepository.findTaggedSchedulesOfMembersRangeIn(any(), any(), any(), any())).thenReturn(emptyList())
        whenever(dutyRepository.findByDutyDateAndMemberIn(any(), any())).thenReturn(emptyList())

        val relation1 = FriendRelation(member, friend1).apply {
            isFamily = true
            pinOrder = 2
        }
        val relation2 = FriendRelation(member, friend2).apply {
            isFamily = false
            pinOrder = 1
        }
        whenever(friendRelationRepository.findAllByMember(member)).thenReturn(listOf(relation1, relation2))

        val requestFrom = friendRequestWithId(10L, from = friend1, to = member)
        val requestTo = friendRequestWithId(11L, from = member, to = friend2)
        whenever(friendService.getPendingRequestsFrom(member)).thenReturn(listOf(requestFrom))
        whenever(friendService.getPendingRequestsTo(member)).thenReturn(listOf(requestTo))

        val result = dashboardService.friend(loginMember)

        assertThat(result.friends).hasSize(2)
        assertThat(result.friends.first().member.id).isEqualTo(friend2.id)
        assertThat(result.friends.map(DashboardFriendDetail::pinOrder)).containsExactly(1, 2)
        assertThat(result.pendingRequestsFrom.first().id).isEqualTo(10L)
        assertThat(result.pendingRequestsTo.first().id).isEqualTo(11L)
    }

    @Test
    fun `friend hides tagged schedule when visibility is not allowed`() {
        val team = Team("team")
        val member = memberWithId(1L, team)
        val family = memberWithId(2L, team)
        val friend = memberWithId(3L, team)
        val owner = memberWithId(4L, team)
        val loginMember = LoginMember(id = 1L, name = "user")

        whenever(memberRepository.findMemberWithTeam(1L)).thenReturn(Optional.of(member))
        whenever(friendRelationRepository.findAllByMember(member)).thenReturn(
            listOf(
                FriendRelation(member, family).apply { isFamily = true },
                FriendRelation(member, friend)
            )
        )
        whenever(friendService.getPendingRequestsFrom(member)).thenReturn(emptyList())
        whenever(friendService.getPendingRequestsTo(member)).thenReturn(emptyList())
        whenever(friendService.buildScheduleVisibilityMap(eq(loginMember), any())).thenReturn(
            mapOf(
                family.id!! to Visibility.family(),
                friend.id!! to Visibility.friends()
            )
        )

        val taggedSchedule = Schedule(
            member = owner,
            content = "family only",
            startDateTime = fixedDate.atStartOfDay(),
            endDateTime = fixedDate.atTime(1, 0),
            visibility = Visibility.FAMILY
        ).apply {
            addTag(family)
            addTag(friend)
        }

        whenever(scheduleRepository.findSchedulesOfMembersRangeIn(any(), any(), any(), any())).thenReturn(emptyList())
        whenever(scheduleRepository.findTaggedSchedulesOfMembersRangeIn(any(), any(), any(), any())).thenAnswer { invocation ->
            val visibilities = invocation.getArgument<Collection<Visibility>>(3)
            if (visibilities.contains(Visibility.FAMILY) && !visibilities.contains(Visibility.PRIVATE)) {
                listOf(taggedSchedule)
            } else {
                emptyList()
            }
        }
        whenever(dutyRepository.findByDutyDateAndMemberIn(any(), any())).thenReturn(emptyList())

        val result = dashboardService.friend(loginMember)

        val familyResult = result.friends.first { it.member.id == family.id }
        val friendResult = result.friends.first { it.member.id == friend.id }

        assertThat(familyResult.schedules).hasSize(1)
        assertThat(friendResult.schedules).isEmpty()
    }

    private fun memberWithId(id: Long, team: Team?): Member {
        val member = Member("user$id", "user$id@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        member.team = team
        return member
    }

    private fun friendRequestWithId(id: Long, from: Member, to: Member): FriendRequest {
        val request = FriendRequest(
            fromMember = from,
            toMember = to,
            status = FriendRequestStatus.PENDING,
            requestType = FriendRequestType.FRIEND_REQUEST
        )
        val field = FriendRequest::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(request, id)
        return request
    }
}
