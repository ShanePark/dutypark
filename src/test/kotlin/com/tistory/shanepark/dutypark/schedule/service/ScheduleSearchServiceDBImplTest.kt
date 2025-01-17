package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable
import java.time.LocalDateTime

class ScheduleSearchServiceDBImplTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var scheduleSearchServiceDBImpl: ScheduleSearchService

    @Autowired
    lateinit var scheduleService: ScheduleService

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

    private fun makeSchedule(
        loginMember: LoginMember, title: String, date: LocalDateTime
    ): Schedule {
        return scheduleService.createSchedule(
            loginMember,
            ScheduleUpdateDto(
                loginMember.id,
                title,
                Visibility.FRIENDS,
                date,
                date
            )
        )
    }

}
