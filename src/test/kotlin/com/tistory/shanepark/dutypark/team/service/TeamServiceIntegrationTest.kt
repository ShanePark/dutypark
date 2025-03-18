package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.service.DutyService
import com.tistory.shanepark.dutypark.team.domain.dto.TeamCreateDto
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Assertions.assertThrows
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.Pageable
import java.time.LocalDate

class TeamServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    private lateinit var service: TeamService

    @Test
    fun findAllWithMemberCount() {
        val initial = teamRepository.findAllWithMemberCount(Pageable.ofSize(10))
        assertThat(initial.content.map { d -> d.id }).containsExactly(TestData.team.id, TestData.team2.id)
    }

    @Test
    fun findById() {
        val findOne = service.findByIdWithMembersAndDutyTypes(TestData.team.id!!)
        assertThat(findOne.id).isEqualTo(TestData.team.id)
        assertThat(findOne.name).isEqualTo(TestData.team.name)
    }

    @Test
    fun `create team`() {
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val teamCreateDto = TeamCreateDto("teamName", "teamDesc")
        val create = service.create(teamCreateDto)
        assertThat(create.id).isNotNull
        assertThat(create.name).isEqualTo(teamCreateDto.name)
        assertThat(create.description).isEqualTo(teamCreateDto.description)
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
    }

    @Test
    fun `delete Team success`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val created = service.create(TeamCreateDto("teamName", "teamDesc"))
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)

        // When
        service.delete(created.id)

        // Then
        val totalAfterDelete = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfterDelete).isEqualTo(totalBefore)
    }

    @Test
    fun `can not delete invalid team id`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements

        // When
        assertThrows<NoSuchElementException> {
            service.delete(9999)
        }

        // Then
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore)
    }

    @Test
    fun `can't delete team containing member`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val created = service.create(TeamCreateDto("teamName", "teamDesc"))
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
        val team = teamRepository.findById(created.id).orElseThrow()

        team.addMember(TestData.member)
        team.addMember(TestData.member2)

        // When
        assertThrows<IllegalStateException> {
            service.delete(created.id)
        }
    }

    @Test
    fun `When delete team containing duty types, all associated dutyTypes will be removed as well`() {
        // Given
        val totalBefore = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        val created = service.create(TeamCreateDto("teamName", "teamDesc"))
        val totalAfter = service.findAllWithMemberCount(Pageable.ofSize(10)).totalElements
        assertThat(totalAfter).isEqualTo(totalBefore + 1)
        val team = teamRepository.findById(created.id).orElseThrow()

        val dutyType1 = team.addDutyType("오전")
        val dutyType2 = team.addDutyType("오후")
        val dutyType3 = team.addDutyType("야간")
        em.flush()

        assertThat(dutyType1.id).isNotNull
        assertThat(dutyType2.id).isNotNull
        assertThat(dutyType3.id).isNotNull

        assertThat(team.dutyTypes).hasSize(3)

        // When
        service.delete(created.id)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType1.id!!)).isEmpty
        assertThat(dutyTypeRepository.findById(dutyType2.id!!)).isEmpty
        assertThat(dutyTypeRepository.findById(dutyType3.id!!)).isEmpty
        assertThat(teamRepository.findById(team.id!!)).isEmpty
    }

    @Test
    fun `When Team is deleted, All related duties will removed`(
        @Autowired dutyService: DutyService,
        @Autowired dutyRepository: DutyRepository
    ) {
        // Given
        val created = service.create(TeamCreateDto("teamName", "teamDesc"))
        val team = teamRepository.findById(created.id).orElseThrow()
        val member = TestData.member

        team.addMember(member)
        val dutyType1 = team.addDutyType("오전")
        em.flush()

        val dutyUpdateDto =
            DutyUpdateDto(year = 2023, month = 4, day = 8, dutyTypeId = dutyType1.id!!, memberId = member.id!!)
        dutyService.update(dutyUpdateDto)

        val duties = dutyService.getDutiesAsMap(member, 2023, 4)
        assertThat(duties.size).isEqualTo(1)
        val duty = duties[8]
        assertThat(duty).isNotNull

        // When
        team.removeMember(member)
        service.delete(team.id!!)

        // Then
        assertThat(dutyTypeRepository.findById(dutyType1.id!!)).isEmpty
        assertThat(teamRepository.findById(team.id!!)).isEmpty

        val theDuty = dutyRepository.findByMemberAndDutyDate(member = member, dutyDate = LocalDate.of(2023, 4, 8))
        assertThat(theDuty).isNull()
    }

    @Test
    fun `can't add same name DutyType on one Team`() {
        // Given
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val dutyType1 = team.addDutyType("test1")
        val dutyType2 = team.addDutyType("test2")
        val dutyType3 = team.addDutyType("test3")
        em.flush()

        assertThat(dutyType1.id).isNotNull
        assertThat(dutyType2.id).isNotNull
        assertThat(dutyType3.id).isNotNull

        assertThat(team.dutyTypes).containsAll(listOf(dutyType1, dutyType2, dutyType3))

        // When
        assertThrows<IllegalArgumentException> {
            team.addDutyType("test1")
        }
    }

    @Test
    fun `Delete member from Team Test`() {
        // Given
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(team.members).hasSize(2)
        assertThat(member.team).isEqualTo(team)
        assertThat(member2.team).isEqualTo(team)

        // When
        service.removeMemberFromTeam(team.id!!, member.id!!)
        service.removeMemberFromTeam(team.id!!, member2.id!!)

        // Then
        assertThat(team.members).isEmpty()
        assertThat(member.team).isNull()
        assertThat(member2.team).isNull()
    }

    @Test
    fun `can't delete member from team if not member of team`() {
        // Given
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val team2 = teamRepository.findById(TestData.team2.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(team2.members).isEmpty()
        assertThat(member.team).isEqualTo(team)
        assertThat(member2.team).isEqualTo(team)

        // When
        assertThrows<IllegalStateException> {
            service.removeMemberFromTeam(team2.id!!, member.id!!)
        }
    }

    @Test
    fun `add Member to Team Test`() {
        // Given
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        team.removeMember(member)
        team.removeMember(member2)
        assertThat(team.members).hasSize(0)
        assertThat(member.team).isEqualTo(null)
        assertThat(member2.team).isEqualTo(null)

        // When
        service.addMemberToTeam(team.id!!, member.id!!)
        service.addMemberToTeam(team.id!!, member2.id!!)

        em.flush()
        em.clear()

        // Then
        val team1 = teamRepository.findById(team.id!!).orElseThrow()
        assertThat(team1.members).hasSize(2)
        assertThat(member.team?.id).isEqualTo(team1.id)
        assertThat(member2.team?.id).isEqualTo(team1.id)
    }

    @Test
    fun `can't add member to team if already member of team`() {
        // Given
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(team.members).hasSize(2)
        assertThat(member.team).isEqualTo(team)
        assertThat(member2.team).isEqualTo(team)

        // When
        assertThrows(IllegalStateException::class.java) {
            service.addMemberToTeam(team.id!!, member.id!!)
        }
        assertThrows(IllegalStateException::class.java) {
            service.addMemberToTeam(team.id!!, member2.id!!)
        }

        // Then
        assertThat(team.members).hasSize(2)
        assertThat(member.team).isEqualTo(team)
        assertThat(member2.team).isEqualTo(team)
    }

    @Test
    fun `change team admin`() {
        // Given
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val member = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val member2 = memberRepository.findById(TestData.member2.id!!).orElseThrow()
        assertThat(team.members).hasSize(2)
        assertThat(member.team).isEqualTo(team)
        assertThat(member2.team).isEqualTo(team)
        assertThat(team.admin).isNull()

        // Then
        service.changeTeamAdmin(team.id!!, member.id!!)
        assertThat(team.admin).isEqualTo(member)

        service.changeTeamAdmin(team.id!!, member2.id!!)
        assertThat(team.admin).isEqualTo(member2)

        service.changeTeamAdmin(team.id!!, null)
        assertThat(team.admin).isNull()

    }

    @Test
    fun `update default duty success`() {
        // Given
        val team = service.create(TeamCreateDto("teamName", "teamDesc"))

        // When
        val updatedDutyName = "newDutyName"
        val updatedDutyColor = Color.RED
        service.updateDefaultDuty(team.id, updatedDutyName, updatedDutyColor.name)

        // Then
        val updated = teamRepository.findById(team.id).orElseThrow()
        assertThat(updated.defaultDutyName).isEqualTo(updatedDutyName)
        assertThat(updated.defaultDutyColor).isEqualTo(updatedDutyColor)
    }


    @Test
    fun `addTeamManager success`() {
        // Given
        val member = TestData.member

        // When
        service.addTeamManager(teamId = TestData.team.id!!, memberId = member.id!!)

        // Then
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.managers.any { it.member.id == member.id }).isTrue()
    }

    @Test
    fun `can not be another team's manager`() {
        // Given
        val member = TestData.member

        // Then
        assertThrows<IllegalStateException> {
            service.addTeamManager(teamId = TestData.team2.id!!, memberId = member.id!!)
        }
    }

    @Test
    fun `nothing happens when add a team manager who is already a manager`() {
        // Given
        val member = TestData.member
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()

        // When
        service.addTeamManager(teamId = TestData.team.id!!, memberId = member.id!!)
        assertThat(team.managers.any { it.member.id == member.id }).isTrue()

        // Then
        service.addTeamManager(teamId = TestData.team.id!!, memberId = member.id!!)
        assertThat(team.managers.any { it.member.id == member.id }).isTrue()
    }

    @Test
    fun `remove team manager success`() {
        // Given
        val member = TestData.member
        service.addTeamManager(teamId = TestData.team.id!!, memberId = member.id!!)
        var team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.managers.any { it.member.id == member.id }).isTrue()

        // When
        service.removeTeamManager(teamId = TestData.team.id!!, memberId = member.id!!)

        // Then
        team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.managers.any { it.member.id == member.id }).isFalse()
    }

    @Test
    fun `nothing happens when trying to remove a member from manager who is not actually a manager`() {
        // Given
        val member = TestData.member
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team.managers.any { it.member.id == member.id }).isFalse()

        // When
        service.removeTeamManager(teamId = TestData.team.id!!, memberId = member.id!!)

        // Then
        val team2 = teamRepository.findById(TestData.team.id!!).orElseThrow()
        assertThat(team2.managers.any { it.member.id == member.id }).isFalse()
    }

    @Test
    fun `exception is thrown when trying to remove from manager who is actually not in the team`() {
        // Given
        val member = TestData.member

        // When
        assertThrows<IllegalStateException> {
            service.removeTeamManager(teamId = TestData.team2.id!!, memberId = member.id!!)
        }
    }


}
