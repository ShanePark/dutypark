package com.tistory.shanepark.dutypark.schedule.timeparsing.domain

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDateTime
import java.util.UUID

class ScheduleTimeParsingTaskTest {

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
        schedule.lastModifiedDate = LocalDateTime.now().plusSeconds(5)

        val expired = task.isExpired(schedule)

        assertThat(expired).isTrue
    }

    @Test
    fun `isExpired returns false when schedule unchanged`() {
        val schedule = scheduleWithMember()
        val task = ScheduleTimeParsingTask(schedule.getId())
        schedule.lastModifiedDate = LocalDateTime.now().minusSeconds(5)

        val expired = task.isExpired(schedule)

        assertThat(expired).isFalse
    }

    private fun scheduleWithMember(): Schedule {
        val member = Member("user", "user@duty.park", "pass")
        return Schedule(
            member = member,
            content = "content",
            startDateTime = LocalDateTime.now(),
            endDateTime = LocalDateTime.now().plusHours(1),
            position = 0
        )
    }
}
