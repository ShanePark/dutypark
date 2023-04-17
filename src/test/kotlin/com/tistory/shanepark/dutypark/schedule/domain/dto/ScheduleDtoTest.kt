package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDateTime
import java.time.YearMonth

class ScheduleDtoTest {

    @Test
    fun `Long day Schedule on same month`() {
        // Given
        val member = Member(name = "name", email = "email", password = "pass")
        val from = LocalDateTime.of(2021, 1, 5, 0, 0)
        val end = LocalDateTime.of(2021, 1, 8, 0, 0)
        val schedule = Schedule(member, "content", from, end, 1)

        // When
        val list = ScheduleDto.of(YearMonth.of(2021, 1), schedule)

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
        val member = Member(name = "name", email = "email", password = "pass")
        val from = LocalDateTime.of(2020, 12, 30, 0, 0)
        val end = LocalDateTime.of(2021, 1, 3, 23, 59)
        val schedule = Schedule(member, "content", from, end, 1)

        // When
        val list = ScheduleDto.of(YearMonth.of(2021, 1), schedule)

        // Then
        assertThat(list).hasSize(3)
        assertThat(list[0].dayOfMonth).isEqualTo(1)
        assertThat(list[0].daysFromStart).isEqualTo(3)
        assertThat(list[0].totalDays).isEqualTo(5)

        assertThat(list[1].dayOfMonth).isEqualTo(2)
        assertThat(list[1].daysFromStart).isEqualTo(4)
        assertThat(list[1].totalDays).isEqualTo(5)

        assertThat(list[2].dayOfMonth).isEqualTo(3)
        assertThat(list[2].daysFromStart).isEqualTo(5)
        assertThat(list[2].totalDays).isEqualTo(5)
    }

    @Test
    fun `empty if there is no schedule on the month`() {
        // Given
        val member = Member(name = "name", email = "email", password = "pass")
        val day = LocalDateTime.of(2023, 4, 17, 0, 0)
        val schedule = Schedule(member, "content", day, day, 1)

        // When
        val list = ScheduleDto.of(YearMonth.of(2023, 3), schedule)
        assertThat(list).isEmpty()
    }

    @Test
    fun `One day Schedule`() {
        // Given
        val member = Member(name = "name", email = "email", password = "pass")
        val day = LocalDateTime.of(2023, 4, 17, 0, 0)
        val schedule = Schedule(member, "content", day, day, 1)

        // When
        val list = ScheduleDto.of(YearMonth.of(2023, 4), schedule)
        assertThat(list.size).isEqualTo(1)
        assertThat(list[0].dayOfMonth).isEqualTo(17)
        assertThat(list[0].daysFromStart).isEqualTo(1)
        assertThat(list[0].totalDays).isEqualTo(1)
        assertThat(list[0].content).isEqualTo(schedule.content)
    }

}

