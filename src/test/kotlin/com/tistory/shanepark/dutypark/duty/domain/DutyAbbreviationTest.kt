package com.tistory.shanepark.dutypark.duty.domain

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.team.domain.dto.TeamDto
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import java.time.LocalDate

class DutyAbbreviationTest {
    @Test
    fun `unset and blank overrides use the first complete character`() {
        for (override in listOf(null, "", "  ")) {
            assertThat(DutyAbbreviation.resolve("야간근무", override)).isEqualTo("야")
        }
        assertThat(DutyAbbreviation.resolve("🌙야간")).isEqualTo("🌙")
        assertThat(DutyAbbreviation.resolve("👩‍⚕️근무")).isEqualTo("👩‍⚕️")
        assertThat(DutyAbbreviation.resolve("e\u0301vening")).isEqualTo("e\u0301")
        assertThat(DutyAbbreviation.resolve("")).isEmpty()
        assertThat(DutyAbbreviation.normalize("  ")).isNull()
        assertThat(DutyAbbreviation.normalize(" N ")).isEqualTo("N")
        assertThat(DutyAbbreviation.normalize(" n ")).isEqualTo("n")
        assertThat(DutyAbbreviation.normalize("nAb")).isEqualTo("nAb")
        assertThat(DutyAbbreviation.normalize("NNNN")).isNull()
    }

    @Test
    fun `client overrides accept up to three ASCII letters or complete Korean syllables`() {
        assertThat(DutyAbbreviation.normalizeAndValidate(" n ")).isEqualTo("n")
        assertThat(DutyAbbreviation.normalizeAndValidate("nAb")).isEqualTo("nAb")
        assertThat(DutyAbbreviation.normalizeAndValidate(" 출 ")).isEqualTo("출")
        assertThat(DutyAbbreviation.normalizeAndValidate("  ")).isNull()
        assertThat(DutyAbbreviation.normalizeAndValidate(null)).isNull()

        for (value in listOf("NNNN", "1", "ㄱ", "😀", "é")) {
            val exception = assertThrows<IllegalArgumentException> {
                DutyAbbreviation.normalizeAndValidate(value)
            }
            assertThat(exception.message).isEqualTo("dutyType.abbreviation.invalid")
        }
    }

    @Test
    fun `automatic abbreviation follows a rename while an explicit override is retained`() {
        val type = DutyType("야간근무", 0, Team("team"), "#112233")
        assertThat(type.abbreviation).isNull()
        assertThat(type.shortName).isEqualTo("야")
        type.name = "주간근무"
        assertThat(type.shortName).isEqualTo("주")
        type.abbreviation = "N"
        type.name = "심야근무"
        assertThat(type.shortName).isEqualTo("N")
        assertThat(type.name).isEqualTo("심야근무")
        type.abbreviation = null
        assertThat(type.shortName).isEqualTo("심")
    }

    @Test
    fun `team and daily payloads retain full names alongside abbreviations including default off`() {
        val team = Team("team").apply {
            defaultDutyName = "휴무"
            defaultDutyAbbreviation = "O"
        }
        val type = team.addDutyType("야간근무", "#112233").apply { abbreviation = "N" }
        val types = TeamDto.of(team, emptyList(), listOf(type)).dutyTypes
        assertThat(types.map { it.name }).containsExactly("휴무", "야간근무")
        assertThat(types.map { it.shortName }).containsExactly("O", "N")
        assertThat(types.map { it.abbreviation }).containsExactly("O", "N")
        val off = DutyDto.offDuty(LocalDate.of(2026, 9, 8), team)
        assertThat(off.dutyType).isEqualTo("휴무")
        assertThat(off.dutyAbbreviation).isEqualTo("O")
        team.defaultDutyAbbreviation = null
        assertThat(DutyDto.offDuty(LocalDate.of(2026, 9, 8), team).dutyAbbreviation).isEqualTo("휴")
    }

    @Test
    fun `type DTO copies recompute the automatic label from the current name`() {
        val type = DutyTypeDto(teamId = 1, name = "야간근무", position = 0, color = "#112233")
        assertThat(type.copy(name = "주간근무").shortName).isEqualTo("주")
        assertThat(type.copy(abbreviation = " N ").shortName).isEqualTo("N")
    }
}
