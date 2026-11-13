package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendDetail
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

class DashboardFriendVisibilityTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var dashboardService: DashboardService

    @Autowired
    lateinit var dutyRepository: DutyRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var clock: Clock

    @Test
    fun `friend with private calendar shows profile but hides duty and schedules`() {
        val friend = otherTeamFriendWithTodayDutyAndSchedule(Visibility.PRIVATE)

        val result = friendDetail(friend)

        assertThat(result.member.name).isEqualTo(friend.name)
        assertThat(result.duty).isNull()
        assertThat(result.schedules).isEmpty()
    }

    @Test
    fun `friend with family calendar hides duty and schedules from a non-family friend`() {
        val friend = otherTeamFriendWithTodayDutyAndSchedule(Visibility.FAMILY)

        val result = friendDetail(friend)

        assertThat(result.member.name).isEqualTo(friend.name)
        assertThat(result.isFamily).isFalse
        assertThat(result.duty).isNull()
        assertThat(result.schedules).isEmpty()
    }

    @Test
    fun `friend with friends calendar shows duty and schedules to a friend`() {
        val friend = otherTeamFriendWithTodayDutyAndSchedule(Visibility.FRIENDS)

        val result = friendDetail(friend)

        assertThat(result.duty?.dutyType).isEqualTo("F-DUTY")
        assertThat(result.schedules.map { it.content }).containsExactly("friend schedule")
    }

    @Test
    fun `friend with family calendar shows duty and schedules to family`() {
        val friend = otherTeamFriendWithTodayDutyAndSchedule(Visibility.FAMILY)
        makeThemFamily(TestData.member, friend)

        val result = friendDetail(friend)

        assertThat(result.isFamily).isTrue
        assertThat(result.duty?.dutyType).isEqualTo("F-DUTY")
        assertThat(result.schedules.map { it.content }).containsExactly("friend schedule")
    }

    @Test
    fun `managed friend with private calendar shows duty and schedules to the manager`() {
        val friend = otherTeamFriendWithTodayDutyAndSchedule(Visibility.PRIVATE)
        makeManagerRelation(manager = TestData.member, managed = friend)
        em.flush()
        em.clear()

        val result = friendDetail(friend)

        assertThat(result.duty?.dutyType).isEqualTo("F-DUTY")
        assertThat(result.schedules.map { it.content }).containsExactly("friend schedule")
    }

    @Test
    fun `teammate friend with private calendar keeps duty like the duty calendar but hides schedules`() {
        val teammate = TestData.member2
        makeThemFriend(TestData.member, teammate)
        dutyRepository.save(Duty(dutyDate = today(), dutyType = TestData.dutyTypes[0], member = teammate))
        saveTodaySchedule(teammate)
        updateVisibility(teammate, Visibility.PRIVATE)
        em.flush()
        em.clear()

        val result = friendDetail(teammate)

        assertThat(result.duty?.dutyType).isEqualTo(TestData.dutyTypes[0].name)
        assertThat(result.schedules).isEmpty()
    }

    private fun otherTeamFriendWithTodayDutyAndSchedule(calendarVisibility: Visibility): Member {
        val friend = memberRepository.save(
            Member(name = "friend3", email = "other-friend@duty.park", password = "pass")
                .apply { team = TestData.team2 }
        )
        val dutyType = dutyTypeRepository.save(DutyType("F-DUTY", 0, TestData.team2, "#123456"))
        makeThemFriend(TestData.member, friend)
        dutyRepository.save(Duty(dutyDate = today(), dutyType = dutyType, member = friend))
        saveTodaySchedule(friend)
        updateVisibility(friend, calendarVisibility)
        em.flush()
        em.clear()
        return friend
    }

    private fun saveTodaySchedule(owner: Member) {
        val noon = today().atTime(12, 0)
        scheduleRepository.save(
            Schedule(
                member = owner,
                content = "friend schedule",
                startDateTime = noon,
                endDateTime = noon.plusHours(1),
                visibility = Visibility.FRIENDS,
            )
        )
    }

    private fun makeThemFamily(member1: Member, member2: Member) {
        friendRelationRepository.findByMemberAndFriend(member1, member2)!!.isFamily = true
        friendRelationRepository.findByMemberAndFriend(member2, member1)!!.isFamily = true
        em.flush()
        em.clear()
    }

    private fun friendDetail(friend: Member): DashboardFriendDetail {
        return dashboardService.friend(loginMember(TestData.member))
            .friends.single { it.member.id == friend.id }
    }

    private fun today(): LocalDate = LocalDate.now(clock.withZone(ZoneId.of("Asia/Seoul")))
}
