package com.tistory.shanepark.dutypark.duty.domain

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.jsonMapper
import jakarta.validation.Validation
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test

class DutyAbbreviationRequestTest {
    private val mapper = jsonMapper()

    @Test
    fun `update distinguishes omitted abbreviation from explicit null and empty string`() {
        val base = "\"id\":1,\"name\":\"야간근무\",\"color\":\"#112233\""
        val omitted = mapper.readValue("{$base}", DutyTypeUpdateDto::class.java)
        assertThat(omitted.abbreviationSpecified).isFalse()
        for (value in listOf("null", "\"\"", "\"  \"", "\"N\"")) {
            val request = mapper.readValue("{$base,\"abbreviation\":$value}", DutyTypeUpdateDto::class.java)
            assertThat(request.abbreviationSpecified).isTrue()
        }
        val custom = mapper.readValue("{$base,\"abbreviation\":\"N\"}", DutyTypeUpdateDto::class.java)
        assertThat(custom.abbreviation).isEqualTo("N")
        assertThat(mapper.writeValueAsString(custom)).doesNotContain("abbreviationSpecified")
    }

    @Test
    fun `optional abbreviations are validated on both request types`() {
        Validation.buildDefaultValidatorFactory().use { factory ->
            val validator = factory.validator
            assertThat(validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233"))).isEmpty()
            assertThat(validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233", "N"))).isEmpty()
            assertThat(validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233", "nAb"))).isEmpty()
            assertThat(validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233", "출근"))).isEmpty()
            assertThat(validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233", " n "))).isEmpty()
            assertThat(validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233", "  "))).isEmpty()
            for (value in listOf("NNNN", "1", "ㄱ", "😀", "é")) {
                val createErrors = validator.validate(DutyTypeCreateDto(1, "야간근무", "#112233", value))
                val updateErrors = validator.validate(DutyTypeUpdateDto(1, "야간근무", "#112233").apply {
                    abbreviation = value
                })
                assertThat(createErrors.map { it.message }).contains("dutyType.abbreviation.invalid")
                assertThat(updateErrors.map { it.message }).contains("dutyType.abbreviation.invalid")
            }
        }
    }
}
