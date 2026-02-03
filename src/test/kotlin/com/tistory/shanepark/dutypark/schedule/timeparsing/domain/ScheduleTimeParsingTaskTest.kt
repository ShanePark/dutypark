package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDateTime
import java.util.UUID

class ScheduleTimeParsingTaskTest {

    // ScheduleTimeParsingTask captures LocalDateTime.now() as requestDateTime
    // So test dates must be relative to the actual current time
    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)
    private val farFuture = LocalDateTime.of(2099, 12, 31, 23, 59, 59)
    private val farPast = LocalDateTime.of(2000, 1, 1, 0, 0, 0)

    @Test
    fun `isExpired throws when schedule id mismatches`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(UUID.randomUUID())

        assertThrows<IllegalArgumentException> {
            task.isExpired(schedule)
        }
    }

    @Test
    fun `isExpired returns true when schedule updated after request`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule.getId())
        // Use far future date to ensure it's always after the task's requestDateTime
        schedule.lastModifiedDate = farFuture

        val expired = task.isExpired(schedule)

        assertThat(expired).isTrue
    }

    @Test
    fun `isExpired returns false when schedule unchanged`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule.getId())
        // Use far past date to ensure it's always before the task's requestDateTime
        schedule.lastModifiedDate = farPast

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
