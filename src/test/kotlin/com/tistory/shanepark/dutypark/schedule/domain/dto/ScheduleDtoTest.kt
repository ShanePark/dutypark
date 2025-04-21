package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class ScheduleDtoTest {
    val member = Member(name = "name", email = "email", password = "pass")

    @Test
    fun `Long day Schedule on same month`() {
        // Given
        val member = member
        val from = LocalDateTime.of(2021, 1, 5, 0, 0)
        val end = LocalDateTime.of(2021, 1, 8, 0, 0)
        val schedule =
            Schedule(member = member, content = "content", startDateTime = from, endDateTime = end, position = 1)

        // When
        val calendarView = CalendarView(2021, 1)
        val list = ScheduleDto.of(calendarView, schedule)

        // Then
        assertThat(list).hasSize(4)
        assertThat(list[0].dayOfMonth).isEqualTo(5)
        assertThat(list[0].daysFromStart).isEqualTo(1)
        assertThat(list[0].totalDays).isEqualTo(4)

        assertThat(list[1].dayOfMonth).isEqualTo(6)
        assertThat(list[1].daysFromStart).isEqualTo(2)
        assertThat(list[1].totalDays).isEqualTo(4)

        assertThat(list[2].dayOfMonth).isEqualTo(7)
        assertThat(list[2].daysFromStart).isEqualTo(3)
        assertThat(list[2].totalDays).isEqualTo(4)

        assertThat(list[3].dayOfMonth).isEqualTo(8)
        assertThat(list[3].daysFromStart).isEqualTo(4)
        assertThat(list[3].totalDays).isEqualTo(4)
    }

    @Test
    fun `Long day Schedule until next month`() {
        // Given
        val from = LocalDateTime.of(2020, 12, 30, 0, 0)
        val end = LocalDateTime.of(2021, 1, 3, 23, 59)
        val schedule =
            Schedule(member = member, content = "content", startDateTime = from, endDateTime = end, position = 1)

        // When
        val calendarView = CalendarView(2021, 1)
        val list = ScheduleDto.of(calendarView, schedule)

        // Then
        assertThat(list).hasSize(5)
        assertThat(list[0].dayOfMonth).isEqualTo(30)
        assertThat(list[0].daysFromStart).isEqualTo(1)
        assertThat(list[0].totalDays).isEqualTo(5)

        assertThat(list[1].dayOfMonth).isEqualTo(31)
        assertThat(list[1].daysFromStart).isEqualTo(2)
        assertThat(list[1].totalDays).isEqualTo(5)

        assertThat(list[2].dayOfMonth).isEqualTo(1)
        assertThat(list[2].daysFromStart).isEqualTo(3)
        assertThat(list[2].totalDays).isEqualTo(5)

        assertThat(list[3].dayOfMonth).isEqualTo(2)
        assertThat(list[3].daysFromStart).isEqualTo(4)

        assertThat(list[4].dayOfMonth).isEqualTo(3)
        assertThat(list[4].daysFromStart).isEqualTo(5)
    }

    @Test
    fun `empty if there is no schedule on the month`() {
        // Given
        val day = LocalDateTime.of(2023, 4, 17, 0, 0)
        val schedule =
            Schedule(member = member, content = "content", startDateTime = day, endDateTime = day, position = 1)

        // When
        val calendarView = CalendarView(2023, 3)
        val list = ScheduleDto.of(calendarView, schedule)
        assertThat(list).isEmpty()
    }

    @Test
    fun `One day Schedule`() {
        // Given
        val day = LocalDateTime.of(2023, 4, 17, 0, 0)
        val schedule =
            Schedule(member = member, content = "content", startDateTime = day, endDateTime = day, position = 1)

        // When
        val calendarView = CalendarView(2023, 4)
        val list = ScheduleDto.of(calendarView, schedule)
        assertThat(list.size).isEqualTo(1)
        assertThat(list[0].dayOfMonth).isEqualTo(17)
        assertThat(list[0].daysFromStart).isEqualTo(1)
        assertThat(list[0].totalDays).isEqualTo(1)
        assertThat(list[0].content).isEqualTo(schedule.content)
    }

    @Test
    fun `Four day schedule but end time is faster than start time`() {
        val start = LocalDateTime.of(2023, 6, 30, 22, 0)
        val end = LocalDateTime.of(2023, 7, 3, 17, 0)
        val schedule =
            Schedule(member = member, content = "content", startDateTime = start, endDateTime = end, position = 0)

        val calendarView = CalendarView(2023, 7)
        val list = ScheduleDto.of(calendarView, schedule)

        assertThat(list.size).isEqualTo(4)
    }

}

