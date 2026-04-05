package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable
import org.springframework.test.context.TestPropertySource
import java.time.LocalDateTime

@TestPropertySource(
    properties = ["spring.jpa.properties.hibernate.query.fail_on_pagination_over_collection_fetch=true"]
)
class ScheduleSearchServiceDBImplTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var scheduleSearchServiceDBImpl: ScheduleSearchService

    @Autowired
    lateinit var scheduleService: ScheduleService

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `search schedules 3 results, it should be sorted by date desc and paged`() {
        val member = TestData.member
        val loginMember = loginMember(member)

        // Given
        makeSchedule(loginMember, "test1", LocalDateTime.of(2024, 1, 1, 0, 0))
        makeSchedule(loginMember, "test2", LocalDateTime.of(2024, 1, 2, 0, 0))
        makeSchedule(loginMember, "test3", LocalDateTime.of(2024, 1, 3, 0, 0))
        makeSchedule(loginMember, "sample1", LocalDateTime.of(2024, 1, 4, 0, 0))
        makeSchedule(loginMember, "sample2", LocalDateTime.of(2024, 1, 5, 0, 0))

        // When
        val result = scheduleSearchServiceDBImpl.search(loginMember, loginMember.id, Pageable.ofSize(10), "test")

        // Then
        assertThat(result.content).hasSize(3)
        assertThat(result.content[0].content).isEqualTo("test3")
        assertThat(result.content[1].content).isEqualTo("test2")
        assertThat(result.content[2].content).isEqualTo("test1")
    }

    @Test
    fun `search schedule 20 results, it should be paginated`() {
        val member = TestData.member
        val loginMember = loginMember(member)

        // Given
        for (i in 1..20) {
            makeSchedule(loginMember, "test$i", LocalDateTime.of(2024, 1, 1, 0, i))
        }

        // When
        val result = scheduleSearchServiceDBImpl.search(loginMember, loginMember.id, Pageable.ofSize(10), "test")

        // Then
        assertThat(result.content).hasSize(10)
        assertThat(result.content[0].content).isEqualTo("test20")
        assertThat(
            scheduleSearchServiceDBImpl.search(
                loginMember,
                loginMember.id,
                Pageable.ofSize(10).next(),
                "INVALID_KEYWORD"
            ).content
        ).hasSize(0)
    }

    @Test
    fun `tagged schedules should be included in the search result`() {
        // Given
        val member1 = TestData.member
        val loginMember = loginMember(member1)
        val member2 = TestData.member2
        val loginMember2 = loginMember(member2)
        makeThemFriend(member1, member2)

        makeSchedule(loginMember, "test1", LocalDateTime.of(2024, 1, 1, 0, 0))
        scheduleService.tagFriend(
            loginMember = loginMember2,
            scheduleId = makeSchedule(
                loginMember2, "test-tagged", LocalDateTime.of(2024, 1, 1, 0, 1)
            ).id,
            friendId = member1.id!!
        )

        // When
        val result = scheduleSearchServiceDBImpl.search(loginMember, loginMember.id, Pageable.ofSize(10), "test")

        // Then
        assertThat(result.content).hasSize(2)
        assertThat(result.content[0].content).isEqualTo("test-tagged")
        assertThat(result.content[1].content).isEqualTo("test1")
    }

    @Test
    fun `search keeps distinct pagination when schedule has multiple tags`() {
        val owner = TestData.member
        val friend1 = TestData.member2
        val friend2 = memberRepository.save(
            Member(
                name = "dummy3",
                email = "test3@duty.park",
                password = TestData.testPass
            )
        )
        makeThemFriend(owner, friend1)
        makeThemFriend(owner, friend2)

        val schedule = makeSchedule(loginMember(owner), "test-multi-tag", LocalDateTime.of(2024, 1, 1, 0, 0))
        scheduleService.tagFriend(loginMember(owner), schedule.id, friend1.id!!)
        scheduleService.tagFriend(loginMember(owner), schedule.id, friend2.id!!)

        val result = scheduleSearchServiceDBImpl.search(
            loginMember(owner),
            owner.id!!,
            Pageable.ofSize(10),
            "test"
        )

        assertThat(result.totalElements).isEqualTo(1)
        assertThat(result.content).hasSize(1)
        assertThat(result.content[0].content).isEqualTo("test-multi-tag")
        assertThat(result.content[0].isTagged).isTrue()

        em.flush()
        em.clear()
        val persisted = scheduleRepository.findById(schedule.id).orElseThrow()
        assertThat(persisted.tags).hasSize(2)
    }

    @Test
    fun `search uses id tie breaker when start times are equal`() {
        val member = TestData.member
        val loginMember = loginMember(member)
        val sameStartTime = LocalDateTime.of(2024, 1, 1, 12, 0)
        val scheduleA = makeSchedule(loginMember, "same-time-a", sameStartTime)
        val scheduleB = makeSchedule(loginMember, "same-time-b", sameStartTime)

        val expectedContents = listOf(scheduleA, scheduleB)
            .sortedByDescending { it.id.toString() }
            .map { it.content }

        val result = scheduleSearchServiceDBImpl.search(
            loginMember,
            loginMember.id,
            Pageable.ofSize(10),
            "same-time"
        )

        assertThat(result.content.map { it.content }).containsExactlyElementsOf(expectedContents)
    }

    private fun makeSchedule(
        loginMember: LoginMember, title: String, date: LocalDateTime
    ): Schedule {
        return scheduleService.createSchedule(
            loginMember,
            ScheduleSaveDto(
                memberId = loginMember.id,
                content = title,
                visibility = Visibility.FRIENDS,
                startDateTime = date,
                endDateTime = date
            )
        )
    }

}
