package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDateTime

class ScheduleTimeParsingTaskTest {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Test
    fun `isExpired throws when schedule id mismatches`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(scheduleWithMember())

        assertThrows<IllegalArgumentException> {
            task.isExpired(schedule)
        }
    }

    @Test
    fun `task expires when parsing input content changes`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule)
        schedule.updateParsingInput(
            content = "updated content",
            startDateTime = schedule.startDateTime,
            endDateTime = schedule.endDateTime,
        )

        val expired = task.isExpired(schedule)

        assertThat(expired).isTrue
        assertThat(schedule.parsingGeneration).isNotEqualTo(task.parsingGeneration)
    }

    @Test
    fun `isExpired returns false when schedule unchanged`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule)

        val expired = task.isExpired(schedule)

        assertThat(expired).isFalse
    }

    @Test
    fun `task expires when parsing input start time changes`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule)
        schedule.updateParsingInput(
            content = schedule.content,
            startDateTime = schedule.startDateTime.plusHours(1),
            endDateTime = schedule.endDateTime,
        )

        val expired = task.isExpired(schedule)

        assertThat(expired).isTrue
    }

    @Test
    fun `task remains expired after parsing input changes away and back`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule)
        val originalContent = schedule.content
        schedule.updateParsingInput(
            content = "temporary content",
            startDateTime = schedule.startDateTime,
            endDateTime = schedule.endDateTime,
        )
        schedule.updateParsingInput(
            content = originalContent,
            startDateTime = schedule.startDateTime,
            endDateTime = schedule.endDateTime,
        )

        val expired = task.isExpired(schedule)

        assertThat(expired).isTrue
    }

    @Test
    fun `each parsing input update creates a distinct generation`() {
        val schedule = scheduleWithMember()
        val initialGeneration = schedule.parsingGeneration

        schedule.updateParsingInput(
            content = "first update",
            startDateTime = schedule.startDateTime,
            endDateTime = schedule.endDateTime,
        )
        val firstGeneration = schedule.parsingGeneration
        schedule.updateParsingInput(
            content = "second update",
            startDateTime = schedule.startDateTime,
            endDateTime = schedule.endDateTime,
        )

        assertThat(firstGeneration).isNotEqualTo(initialGeneration)
        assertThat(schedule.parsingGeneration).isNotIn(initialGeneration, firstGeneration)
    }

    @Test
    fun `task remains current when only unrelated schedule fields change`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule)
        schedule.description = "updated description"
        schedule.lastModifiedDate = LocalDateTime.of(2099, 12, 31, 23, 59, 59)

        val expired = task.isExpired(schedule)

        assertThat(expired).isFalse
    }

    private fun scheduleWithMember(): Schedule {
        val member = Member("user", "user@duty.park", "pass")
        return Schedule(
            member = member,
            content = "content",
            startDateTime = fixedDateTime,
            endDateTime = fixedDateTime.plusHours(1),
            position = 0
        )
    }
}
