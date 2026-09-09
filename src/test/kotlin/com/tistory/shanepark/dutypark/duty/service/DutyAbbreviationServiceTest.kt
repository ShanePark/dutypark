package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.doNothing
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.test.util.ReflectionTestUtils
import java.time.Clock
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class DutyAbbreviationServiceTest {
    @Mock private lateinit var types: DutyTypeRepository
    @Mock private lateinit var teams: TeamRepository
    @Mock private lateinit var duties: DutyRepository
    @Mock private lateinit var content: PublicContentService
    private lateinit var service: DutyTypeService
    private lateinit var team: Team

    @BeforeEach
    fun setUp() {
        team = Team("team")
        ReflectionTestUtils.setField(team, "id", 1L)
        service = DutyTypeService(types, teams, duties, Clock.systemUTC(), content)
    }

    @Test
    fun `create stores only explicit overrides and normalizes blanks`() {
        whenever(teams.findByIdForUpdate(1L)).thenReturn(Optional.of(team))
        val implicit = service.addDutyType(DutyTypeCreateDto(1, "주간근무", "#112233"))
        val custom = service.addDutyType(DutyTypeCreateDto(1, "야간근무", "#112233", " n "))
        val blank = service.addDutyType(DutyTypeCreateDto(1, "저녁근무", "#112233", "  "))
        assertThat(implicit.abbreviation).isNull()
        assertThat(implicit.shortName).isEqualTo("주")
        assertThat(custom.abbreviation).isEqualTo("n")
        assertThat(custom.name).isEqualTo("야간근무")
        assertThat(blank.abbreviation).isNull()
        verify(content).validateContent("n")
    }

    @Test
    fun `create rejects an override that is not one allowed character`() {
        whenever(teams.findByIdForUpdate(1L)).thenReturn(Optional.of(team))

        val exception = assertThrows<IllegalArgumentException> {
            service.addDutyType(DutyTypeCreateDto(1, "야간근무", "#112233", "1/10"))
        }

        assertThat(exception.message).isEqualTo("dutyType.abbreviation.invalid")
        assertThat(team.dutyTypes).isEmpty()
    }

    @Test
    fun `legacy updates preserve explicit overrides while explicit null resets to automatic`() {
        val type = existingType()
        val renamed = service.update(DutyTypeUpdateDto(10, "심야근무", "#445566"))
        assertThat(renamed.abbreviation).isEqualTo("N")
        assertThat(renamed.shortName).isEqualTo("N")
        service.update(DutyTypeUpdateDto(10, "심야근무", "#445566").apply { abbreviation = null })
        assertThat(type.abbreviation).isNull()
        assertThat(type.shortName).isEqualTo("심")
    }

    @Test
    fun `blank updates reset and padded updates trim the override`() {
        val type = existingType()
        service.update(DutyTypeUpdateDto(10, type.name, type.color).apply { abbreviation = "  " })
        assertThat(type.abbreviation).isNull()
        service.update(DutyTypeUpdateDto(10, type.name, type.color).apply { abbreviation = " N " })
        assertThat(type.abbreviation).isEqualTo("N")
    }

    @Test
    fun `preserves lowercase and mixed-case overrides and rejects invalid values`() {
        val type = existingType()
        service.update(DutyTypeUpdateDto(10, type.name, type.color).apply { abbreviation = " n " })
        assertThat(type.abbreviation).isEqualTo("n")

        service.update(DutyTypeUpdateDto(10, type.name, type.color).apply { abbreviation = "nAb" })
        assertThat(type.abbreviation).isEqualTo("nAb")

        val exception = assertThrows<IllegalArgumentException> {
            service.update(DutyTypeUpdateDto(10, type.name, type.color).apply { abbreviation = "ㄱ" })
        }
        assertThat(exception.message).isEqualTo("dutyType.abbreviation.invalid")
        assertThat(type.abbreviation).isEqualTo("nAb")
    }

    @Test
    fun `blocked abbreviations are rejected before changing any state`() {
        val type = existingType()
        doNothing().whenever(content).validateContent("changed")
        doThrow(BadRequestException("contentFilter.blocked")).whenever(content).validateContent("X")
        assertThrows<BadRequestException> {
            service.update(DutyTypeUpdateDto(10, "changed", "#445566").apply { abbreviation = "X" })
        }
        assertThat(type.name).isEqualTo("야간근무")
        assertThat(type.color).isEqualTo("#112233")
        assertThat(type.abbreviation).isEqualTo("N")
    }

    private fun existingType(): DutyType {
        val type = team.addDutyType("야간근무", "#112233").apply { abbreviation = "N" }
        ReflectionTestUtils.setField(type, "id", 10L)
        whenever(types.findById(10L)).thenReturn(Optional.of(type))
        whenever(teams.findByIdWithDutyTypes(1L)).thenReturn(Optional.of(team))
        return type
    }
}
