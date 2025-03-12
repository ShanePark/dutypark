package com.tistory.shanepark.dutypark.schedule.domain.dto

import jakarta.validation.Validation
import jakarta.validation.Validator
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Assertions
import org.junit.jupiter.api.Test
import java.time.LocalDateTime

class scheduleSaveDtoTest {

    private val validator: Validator = Validation.buildDefaultValidatorFactory().validator

    @Test
    fun `scheduleUpdateDto should have content`() {
        val scheduleSaveDto = ScheduleSaveDto(
            memberId = 0L,
            content = " ",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val validation = validator.validate(scheduleSaveDto)
        assertThat(validation).hasSize(1)
        validation.iterator().next().let {
            assertThat(it.propertyPath.toString()).isEqualTo("content")
            assertThat(it.message).isEqualTo("must not be blank")
        }
    }

    @Test
    fun `schedule content should not be longer than 50 characters`() {
        val contentLength51 = IntRange(1, 51).joinToString("") { "a" }

        val scheduleSaveDto = ScheduleSaveDto(
            memberId = 0L,
            content = contentLength51,
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 11, 0, 0),
        )
        val validation = validator.validate(scheduleSaveDto)
        assertThat(validation).hasSize(1)
        validation.iterator().next().let {
            assertThat(it.propertyPath.toString()).isEqualTo("content")
            assertThat(it.message).isEqualTo("length must be between 0 and 50")
        }
    }

    @Test
    fun `validation success if startDateTime and endDateTime are same`() {
        val scheduleSaveDto = ScheduleSaveDto(
            memberId = 1,
            content = "schedule1",
            startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
            endDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
        )
        val validation = validator.validate(scheduleSaveDto)
        assertThat(validation).isEmpty()
    }

    @Test
    fun `validation fail if startDateTime is after EndDateTime`() {
        Assertions.assertThrows(IllegalArgumentException::class.java) {
            ScheduleSaveDto(
                memberId = 1,
                content = "schedule1",
                startDateTime = LocalDateTime.of(2023, 4, 10, 0, 0),
                endDateTime = LocalDateTime.of(2023, 4, 9, 0, 0),
            )
        }
    }
}
