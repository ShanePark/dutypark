package com.tistory.shanepark.dutypark.schedule.domain.dto

import jakarta.validation.Validation
import jakarta.validation.Validator
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class ScheduleUpdateDtoTest {

    private val validator: Validator = Validation.buildDefaultValidatorFactory().validator

    @Test
    fun `validation success if startDateTime and endDateTime are same`() {
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = 1,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val validation = validator.validate(scheduleUpdateDto)
        assertThat(validation).isEmpty()
    }

    @Test
    fun `validation fail if startDateTime is after EndDateTime`() {
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = 1,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 9, 0, 0),
        )
        val validation = validator.validate(scheduleUpdateDto)
        assertThat(validation).hasSize(1)
        validation.iterator().next().let {
            assertThat(it.propertyPath.toString()).isEqualTo("dateRangeValid")
            assertThat(it.message).isEqualTo("StartDateTime must be before or equal to EndDateTime")
        }
    }
}
