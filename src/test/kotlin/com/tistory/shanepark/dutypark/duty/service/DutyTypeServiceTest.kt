package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.test.util.ReflectionTestUtils
import java.util.*

@ExtendWith(MockitoExtension::class)
class DutyTypeServiceTest {

    @Mock
    private lateinit var dutyTypeRepository: DutyTypeRepository

    @Mock
    private lateinit var teamRepository: TeamRepository

    private lateinit var dutyTypeService: DutyTypeService

    private lateinit var team: Team

    @BeforeEach
    fun setUp() {
        dutyTypeService = DutyTypeService(dutyTypeRepository, teamRepository)
        team = Team("testTeam")
        ReflectionTestUtils.setField(team, "id", 1L)
    }

    @Test
    fun `Create duty Type success`() {
        // Given
        val dutyTypeCreateDto = DutyTypeCreateDto(team.id!!, "dutyType", "#f0f8ff")
        `when`(teamRepository.findByIdWithDutyTypes(team.id!!)).thenReturn(Optional.of(team))

        // When
        val created = dutyTypeService.addDutyType(dutyTypeCreateDto)

        // Then
        assertThat(created).isNotNull
        assertThat(created.name).isEqualTo("dutyType")
        assertThat(created.color).isEqualTo("#f0f8ff")
        assertThat(created.team).isEqualTo(team)
        assertThat(team.dutyTypes).contains(created)
    }

    @Test
    fun `can't create same duty type name in same team`() {
        // Given
        `when`(teamRepository.findByIdWithDutyTypes(team.id!!)).thenReturn(Optional.of(team))

        val dutyTypeCreateDto = DutyTypeCreateDto(team.id!!, "dutyType", "#f0f8ff")
        dutyTypeService.addDutyType(dutyTypeCreateDto)

        val dutyTypeCreateDto2 = DutyTypeCreateDto(team.id!!, "dutyType2", "#f0f8ff")
        dutyTypeService.addDutyType(dutyTypeCreateDto2)

        // When & Then
        assertThrows<IllegalArgumentException> {
            dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "dutyType", "#f0f8ff"))
        }
        assertThrows<IllegalArgumentException> {
            dutyTypeService.addDutyType(DutyTypeCreateDto(team.id!!, "dutyType2", "#f0f8ff"))
        }
    }

    @Test
    fun `update duty-type success`() {
        // Given
        val dutyType = DutyType("original", 0, team, "#f0f8ff")
        ReflectionTestUtils.setField(dutyType, "id", 1L)
        team.dutyTypes.add(dutyType)

        `when`(dutyTypeRepository.findById(dutyType.id!!)).thenReturn(Optional.of(dutyType))
        `when`(teamRepository.findByIdWithDutyTypes(team.id!!)).thenReturn(Optional.of(team))

        // When
        val dutyTypeUpdateDto = DutyTypeUpdateDto(dutyType.id!!, "changed", "#aabbcc")
        val updated = dutyTypeService.update(dutyTypeUpdateDto)

        // Then
        assertThat(updated.id).isEqualTo(dutyType.id)
        assertThat(updated.name).isEqualTo("changed")
        assertThat(updated.color).isEqualTo("#aabbcc")
    }

    @Test
    fun `update duty type fails if same name already exist in the team`() {
        // Given
        val dutyType1 = DutyType("dutyType", 0, team, "#f0f8ff")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        val dutyType2 = DutyType("dutyType2", 1, team, "#f0f8ff")
        ReflectionTestUtils.setField(dutyType2, "id", 2L)

        team.dutyTypes.add(dutyType1)
        team.dutyTypes.add(dutyType2)

        `when`(dutyTypeRepository.findById(dutyType1.id!!)).thenReturn(Optional.of(dutyType1))
        `when`(teamRepository.findByIdWithDutyTypes(team.id!!)).thenReturn(Optional.of(team))

        // When & Then
        val dutyTypeUpdateDto = DutyTypeUpdateDto(dutyType1.id!!, dutyType2.name, "#f0f8ff")
        assertThrows<IllegalArgumentException> {
            dutyTypeService.update(dutyTypeUpdateDto)
        }
    }

    @Test
    fun `swap dutyType position`() {
        // Given
        val dutyType1 = DutyType("type1", 0, team, "#f0f8ff")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        val dutyType2 = DutyType("type2", 1, team, "#f0f8ff")
        ReflectionTestUtils.setField(dutyType2, "id", 2L)

        val position1 = dutyType1.position
        val position2 = dutyType2.position

        `when`(dutyTypeRepository.findById(dutyType1.id!!)).thenReturn(Optional.of(dutyType1))
        `when`(dutyTypeRepository.findById(dutyType2.id!!)).thenReturn(Optional.of(dutyType2))

        // When
        dutyTypeService.swapDutyTypePosition(dutyType1.id!!, dutyType2.id!!)

        // Then
        assertThat(dutyType1.position).isEqualTo(position2)
        assertThat(dutyType2.position).isEqualTo(position1)
    }

    @Test
    fun `swap same dutyType should throw exception`() {
        // When & Then
        assertThrows<IllegalArgumentException> {
            dutyTypeService.swapDutyTypePosition(1L, 1L)
        }
    }

}
