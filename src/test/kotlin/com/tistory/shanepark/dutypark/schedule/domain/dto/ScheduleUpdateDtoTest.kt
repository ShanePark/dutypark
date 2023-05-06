package com.tistory.shanepark.dutypark.schedule.domain.dto

import com.tistory.shanepark.dutypark.common.domain.dto.constraint.CreateDtoConstraint
import com.tistory.shanepark.dutypark.common.domain.dto.constraint.UpdateDtoConstraint
import jakarta.validation.Validation
import jakarta.validation.Validator
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import java.time.LocalDateTime
import java.util.*

class ScheduleUpdateDtoTest {

    private val validator: Validator = Validation.buildDefaultValidatorFactory().validator

    @Test
    fun `scheduleUpdateDto should have content`() {
        val scheduleUpdateDto = ScheduleUpdateDto(
            memberId = 0L,
            content = " ",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val validation = validator.validate(scheduleUpdateDto, CreateDtoConstraint::class.java)
        assertThat(validation).hasSize(1)
        validation.iterator().next().let {
            assertThat(it.propertyPath.toString()).isEqualTo("content")
            assertThat(it.message).isEqualTo("must not be blank")
        }
    }

    @Test
    fun `when update schedule, ScheduleUpdateDto should have id`() {
        val scheduleUpdateDto = ScheduleUpdateDto(
            id = null,
            memberId = 1,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val validation = validator.validate(scheduleUpdateDto, UpdateDtoConstraint::class.java)
        assertThat(validation).hasSize(1)
        validation.iterator().next().let {
            assertThat(it.propertyPath.toString()).isEqualTo("id")
            assertThat(it.message).isEqualTo("must not be null")
        }
    }

    @Test
    fun `when create schedule, ScheduleCreateDto should not have id`() {
        val scheduleUpdateDto = ScheduleUpdateDto(
            id = UUID.randomUUID(),
            memberId = 1,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val validation = validator.validate(scheduleUpdateDto, CreateDtoConstraint::class.java)
        assertThat(validation).hasSize(1)
        validation.iterator().next().let {
            assertThat(it.propertyPath.toString()).isEqualTo("id")
            assertThat(it.message).isEqualTo("must be null")
        }
    }

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
