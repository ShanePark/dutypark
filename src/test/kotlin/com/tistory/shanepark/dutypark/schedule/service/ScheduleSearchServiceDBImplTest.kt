package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions
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
        Assertions.assertThat(result).hasSize(3)
        Assertions.assertThat(result.content.get(0).content).isEqualTo("test3")
        Assertions.assertThat(result.content.get(1).content).isEqualTo("test2")
        Assertions.assertThat(result.content.get(2).content).isEqualTo("test1")
    }

    private fun makeSchedule(
        loginMember: LoginMember, title: String, date: LocalDateTime
    ) {
        scheduleService.createSchedule(
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
