package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime
import java.time.YearMonth

class ScheduleServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var scheduleService: ScheduleService

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `Find Schedules`() {
        // given
        val member = TestData.member
        val schedule1 = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        val schedule2 = Schedule(
            member = member,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 12, 0, 0),
            position = 0
        )
        scheduleRepository.saveAll(listOf(schedule1, schedule2))

        // When
        val result = scheduleService.findSchedulesByYearAndMonth(member, YearMonth.of(2023, 4))

        // Then
        assertThat(result).hasSize(30)
        assertThat(result[9 - 1]).hasSize(0)
        assertThat(result[10 - 1]).hasSize(2)
        assertThat(result[11 - 1]).hasSize(1)
        assertThat(result[12 - 1]).hasSize(1)
    }

    @Test
    fun `find schedules over month`() {
        // given
        val member = TestData.member
        val schedule1 = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 3, 30, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 5, 0, 0),
            position = 0
        )
        val schedule2 = Schedule(
            member = member,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 6, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 6, 0, 0),
            position = 0
        )
        scheduleRepository.saveAll(listOf(schedule1, schedule2))

        // When
        val result = scheduleService.findSchedulesByYearAndMonth(member, YearMonth.of(2023, 4))

        // Then
        assertThat(result).hasSize(30)
        val aprilFirst = result[0]
        assertThat(aprilFirst).hasSize(1)
        assertThat(aprilFirst[0].content).isEqualTo(schedule1.content)
        assertThat(aprilFirst[0].dayOfMonth).isEqualTo(1)
        assertThat(aprilFirst[0].totalDays).isEqualTo(7)
        assertThat(aprilFirst[0].daysFromStart).isEqualTo(3)
        assertThat(aprilFirst[0].position).isEqualTo(0)

        assertThat(result[1 - 1]).hasSize(1)
        assertThat(result[2 - 1]).hasSize(1)
        assertThat(result[3 - 1]).hasSize(1)
        assertThat(result[4 - 1]).hasSize(1)
        assertThat(result[5 - 1]).hasSize(1)
        assertThat(result[6 - 1]).hasSize(1)
        for (i in 7..30) {
            assertThat(result[i - 1]).isEmpty()
        }
    }

}
