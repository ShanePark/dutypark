package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime
import java.time.YearMonth

class ScheduleServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var scheduleService: ScheduleService

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Test
    fun `Create schedule success test`() {
        // given
        val member = TestData.member
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val scheduleUpdateDto3 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )

        // When
        val createSchedule1 = scheduleService.createSchedule(scheduleUpdateDto1)
        val createSchedule2 = scheduleService.createSchedule(scheduleUpdateDto2)
        val createSchedule3 = scheduleService.createSchedule(scheduleUpdateDto3)

        // Then
        assertThat(createSchedule1).isNotNull
        val id = createSchedule1.id
        assertThat(id).isNotNull
        val findSchedule = scheduleRepository.findById(id!!).orElseThrow()
        assertThat(findSchedule).isNotNull
        assertThat(findSchedule.content).isEqualTo(scheduleUpdateDto1.content)
        assertThat(findSchedule.startDateTime).isEqualTo(scheduleUpdateDto1.startDateTime)
        assertThat(findSchedule.endDateTime).isEqualTo(scheduleUpdateDto1.endDateTime)
        assertThat(findSchedule.position).isEqualTo(0)

        assertThat(createSchedule2).isNotNull
        assertThat(createSchedule2.position).isEqualTo(0)
        assertThat(createSchedule3.position).isEqualTo(1)
    }

    @Test
    fun `update Schedule Test`() {
        // given
        val member = TestData.member
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        scheduleRepository.save(schedule)
        assertThat(schedule.id).isNotNull

        // When
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val updatedSchedule = scheduleService.updateSchedule(schedule.id, scheduleUpdateDto)

        // Then
        assertThat(updatedSchedule).isNotNull
        assertThat(updatedSchedule.content).isEqualTo(scheduleUpdateDto.content)
        assertThat(updatedSchedule.startDateTime).isEqualTo(scheduleUpdateDto.startDateTime)
        assertThat(updatedSchedule.endDateTime).isEqualTo(scheduleUpdateDto.endDateTime)
        assertThat(updatedSchedule.position).isEqualTo(0)
    }

    @Test
    fun `delete schedule test`() {
        // given
        val member = TestData.member
        val schedule = Schedule(
            member = member,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            position = 0
        )
        scheduleRepository.save(schedule)
        assertThat(schedule.id).isNotNull

        // When
        scheduleService.deleteSchedule(schedule.id)

        em.clear()

        // Then
        val findSchedule = scheduleRepository.findById(schedule.id)
        assertThat(findSchedule).isEmpty
    }

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
        val schedule3 = Schedule(
            member = member,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 12, 0, 0),
            position = 1
        )
        scheduleRepository.saveAll(listOf(schedule1, schedule2, schedule3))

        // When
        val yearMonth = YearMonth.of(2023, 4)
        val result = scheduleService.findSchedulesByYearAndMonth(member, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        assertThat(result).hasSize(calendarView.size)
        val paddingBefore = calendarView.paddingBefore
        assertThat(result[paddingBefore + 9 - 1]).hasSize(0)
        assertThat(result[paddingBefore + 10 - 1]).hasSize(3)
        assertThat(result[paddingBefore + 11 - 1]).hasSize(2)
        assertThat(result[paddingBefore + 12 - 1]).hasSize(2)

        val schedules = result[paddingBefore + 12 - 1]
        assertThat(schedules[0].position).isLessThan(schedules[1].position)

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
        val yearMonth = YearMonth.of(2023, 4)
        val result = scheduleService.findSchedulesByYearAndMonth(member, yearMonth)

        // Then
        val calendarView = CalendarView(yearMonth)
        assertThat(result).hasSize(calendarView.size)
        val paddingBefore = calendarView.paddingBefore

        val lastDayOfMarch = result[paddingBefore - 1]
        assertThat(lastDayOfMarch).hasSize(1)
        assertThat(lastDayOfMarch[0].content).isEqualTo(schedule1.content)
        assertThat(lastDayOfMarch[0].dayOfMonth).isEqualTo(31)
        assertThat(lastDayOfMarch[0].daysFromStart).isEqualTo(2)

        val aprilFirst = result[paddingBefore]
        assertThat(aprilFirst).hasSize(1)
        assertThat(aprilFirst[0].content).isEqualTo(schedule1.content)
        assertThat(aprilFirst[0].dayOfMonth).isEqualTo(1)
        assertThat(aprilFirst[0].totalDays).isEqualTo(7)
        assertThat(aprilFirst[0].daysFromStart).isEqualTo(3)
        assertThat(aprilFirst[0].position).isEqualTo(0)

        assertThat(result[paddingBefore + 1 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 2 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 3 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 4 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 5 - 1]).hasSize(1)
        assertThat(result[paddingBefore + 6 - 1]).hasSize(1)
        for (i in 7..30) {
            assertThat(result[paddingBefore + i - 1]).isEmpty()
        }

        val mayFirst = result[calendarView.paddingBefore + calendarView.lengthOfMonth]
        assertThat(mayFirst).isEmpty()
    }

    @Test
    fun `update Schedule Position test`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto3 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )

        val schedule1 = scheduleService.createSchedule(scheduleUpdateDto1)
        val schedule2 = scheduleService.createSchedule(scheduleUpdateDto2)
        val schedule3 = scheduleService.createSchedule(scheduleUpdateDto3)
        assertThat(schedule1.position).isEqualTo(0)
        assertThat(schedule2.position).isEqualTo(1)
        assertThat(schedule3.position).isEqualTo(2)

        // When
        scheduleService.swapSchedulePosition(schedule1, schedule2)
        em.flush()
        em.clear()

        // Then
        val findSchedule1 = scheduleRepository.findById(schedule1.id)
        val findSchedule2 = scheduleRepository.findById(schedule2.id)
        val findSchedule3 = scheduleRepository.findById(schedule3.id)
        assertThat(findSchedule2.get().position).isEqualTo(0)
        assertThat(findSchedule1.get().position).isEqualTo(1)
        assertThat(findSchedule3.get().position).isEqualTo(2)
    }

    @Test
    fun `Different start date can't update schedule position`() {
        // Given
        val member = TestData.member
        val scheduleUpdateDto1 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto2 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule2",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val scheduleUpdateDto3 = ScheduleUpdateDto(
            memberId = member.id!!,
            content = "schedule3",
            startDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )

        val schedule1 = scheduleService.createSchedule(scheduleUpdateDto1)
        val schedule2 = scheduleService.createSchedule(scheduleUpdateDto2)
        val schedule3 = scheduleService.createSchedule(scheduleUpdateDto3)

        scheduleService.swapSchedulePosition(schedule1, schedule2)
        // Then
        assertThrows<IllegalArgumentException> {
            scheduleService.swapSchedulePosition(schedule2, schedule3)
        }
    }

}
