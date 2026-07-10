package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.service.DutyPatternService
import com.tistory.shanepark.dutypark.duty.service.DutyResolver
import com.tistory.shanepark.dutypark.duty.service.ResolvedDuty
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.ProfilePhotoService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.Mockito.`when`
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDate
import java.util.*

@ExtendWith(MockitoExtension::class)
class TeamServiceTest {

    @InjectMocks
    lateinit var service: TeamService

    @Mock
    lateinit var teamRepository: TeamRepository

    @Mock
    lateinit var dutyTypeRepository: DutyTypeRepository

    @Mock
    lateinit var dutyRepository: DutyRepository

    @Mock
    lateinit var memberRepository: MemberRepository

    @Mock
    lateinit var dutyPatternService: DutyPatternService

    @Mock
    lateinit var dutyResolver: DutyResolver

    @Mock
    lateinit var profilePhotoService: ProfilePhotoService

    @Test
    fun `checkCanManage returns code-first auth exception for non-manager`() {
        val team = Team("Test Team")
        ReflectionTestUtils.setField(team, "id", 1L)
        `when`(teamRepository.findById(1L)).thenReturn(Optional.of(team))

        val exception = assertThrows<AuthException> {
            service.checkCanManage(LoginMember(id = 10L, name = "viewer"), 1L)
        }

        assertThat(exception.message).isEqualTo("team.manage.forbidden")
    }

    @Test
    fun `checkCanAdmin returns code-first auth exception for non-admin`() {
        val team = Team("Test Team")
        val admin = Member(name = "Admin")
        ReflectionTestUtils.setField(team, "id", 1L)
        ReflectionTestUtils.setField(admin, "id", 1L)
        team.changeAdmin(admin)
        `when`(teamRepository.findById(1L)).thenReturn(Optional.of(team))

        val exception = assertThrows<AuthException> {
            service.checkCanAdmin(LoginMember(id = 2L, name = "manager"), 1L)
        }

        assertThat(exception.message).isEqualTo("team.admin.required")
    }

    @Test
    fun `checkCanRead returns code-first auth exception for outsider`() {
        val team = Team("Test Team")
        val outsider = Member(name = "outsider")
        ReflectionTestUtils.setField(team, "id", 1L)
        ReflectionTestUtils.setField(outsider, "id", 3L)
        `when`(teamRepository.findById(1L)).thenReturn(Optional.of(team))
        `when`(memberRepository.findById(3L)).thenReturn(Optional.of(outsider))

        val exception = assertThrows<AuthException> {
            service.checkCanRead(LoginMember(id = 3L, name = "outsider"), 1L)
        }

        assertThat(exception.message).isEqualTo("team.member.required")
    }

    @Test
    fun `loadShift should return empty shift if member is not in any team`() {
        // Given
        val longinMember = LoginMember(id = 1L, name = "test")
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        // When
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(Member(name = "test")))

        val shifts = service.loadShift(loginMember = longinMember, LocalDate.of(2025, 3, 12))

        // Then
        assertThat(shifts).isEmpty()
    }

    @Test
    fun `loadShift should return correct shifts when members have duties`() {
        // Given

        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        val member1 = Member(name = "Alice")
        member1.team = team
        val member2 = Member(name = "Bob")
        member2.team = team
        ReflectionTestUtils.setField(member1, "id", 1L)
        ReflectionTestUtils.setField(member2, "id", 2L)
        val loginMember = LoginMember(id = 1L, name = "test")

        val dutyType1 = DutyType("Type1", 0, team, "#ffb3ba")
        val dutyType2 = DutyType("Type2", 1, team, "#f0f8ff")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        ReflectionTestUtils.setField(dutyType2, "id", 2L)
        val dutyTypes = listOf(
            dutyType1,
            dutyType2
        )

        val dutyDate = LocalDate.of(2025, 3, 12)
        val duty1 = Duty(dutyDate = dutyDate, dutyType = dutyTypes[0], member = member1)
        val duty2 = Duty(dutyDate = dutyDate, dutyType = dutyTypes[1], member = member2)
        ReflectionTestUtils.setField(duty1, "id", 1L)
        ReflectionTestUtils.setField(duty2, "id", 2L)

        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, dutyType2, DutySource.OVERRIDE),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        // When
        val shifts = service.loadShift(loginMember, dutyDate)

        // Then
        assertThat(shifts.size).isEqualTo(3)
        assertThat(shifts[0].members.size).isEqualTo(0)

        assertThat(shifts[1].members.size).isEqualTo(1)
        assertThat(shifts[1].members.first().id).isEqualTo(1L)

        assertThat(shifts[2].members.size).isEqualTo(1)
        assertThat(shifts[2].members.first().id).isEqualTo(2L)
    }

    @Test
    fun `loadShift should include members without duty record in OFF group`() {
        // Given
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        val member1 = Member(name = "Alice")
        member1.team = team
        val member2 = Member(name = "Bob")
        member2.team = team
        ReflectionTestUtils.setField(member1, "id", 1L)
        ReflectionTestUtils.setField(member2, "id", 2L)
        val loginMember = LoginMember(id = 1L, name = "Alice")

        val dutyType1 = DutyType("Work", 0, team, "#ffb3ba")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        val dutyTypes = listOf(dutyType1)

        val dutyDate = LocalDate.of(2025, 3, 12)
        // Only member1 has a duty, member2 has no duty record
        val duty1 = Duty(dutyDate = dutyDate, dutyType = dutyType1, member = member1)
        ReflectionTestUtils.setField(duty1, "id", 1L)

        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        // When
        val shifts = service.loadShift(loginMember, dutyDate)

        // Then
        assertThat(shifts.size).isEqualTo(2) // OFF + Work

        // OFF group should contain member2 (no duty record)
        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(1)
        assertThat(offGroup.members.first().name).isEqualTo("Bob")

        // Work group should contain member1
        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members.size).isEqualTo(1)
        assertThat(workGroup.members.first().name).isEqualTo("Alice")
    }

    @Test
    fun `loadShift should include members with null dutyType in OFF group`() {
        // Given
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        val member1 = Member(name = "Alice")
        member1.team = team
        val member2 = Member(name = "Bob")
        member2.team = team
        ReflectionTestUtils.setField(member1, "id", 1L)
        ReflectionTestUtils.setField(member2, "id", 2L)
        val loginMember = LoginMember(id = 1L, name = "Alice")

        val dutyType1 = DutyType("Work", 0, team, "#ffb3ba")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        val dutyTypes = listOf(dutyType1)

        val dutyDate = LocalDate.of(2025, 3, 12)
        // member1 has Work duty, member2 has duty record with null dutyType (OFF)
        val duty1 = Duty(dutyDate = dutyDate, dutyType = dutyType1, member = member1)
        val duty2 = Duty(dutyDate = dutyDate, dutyType = null, member = member2)
        ReflectionTestUtils.setField(duty1, "id", 1L)
        ReflectionTestUtils.setField(duty2, "id", 2L)

        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, null, DutySource.OVERRIDE),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        // When
        val shifts = service.loadShift(loginMember, dutyDate)

        // Then
        assertThat(shifts.size).isEqualTo(2) // OFF + Work

        // OFF group should contain member2 (duty with null dutyType)
        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(1)
        assertThat(offGroup.members.first().name).isEqualTo("Bob")

        // Work group should contain member1
        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members.size).isEqualTo(1)
        assertThat(workGroup.members.first().name).isEqualTo("Alice")
    }

    @Test
    fun `loadShift should handle mixed scenario with work, null dutyType, and no duty record`() {
        // Given
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        val member1 = Member(name = "Alice")   // has Work duty
        val member2 = Member(name = "Bob")     // has duty with null dutyType
        val member3 = Member(name = "Charlie") // no duty record
        member1.team = team
        member2.team = team
        member3.team = team
        ReflectionTestUtils.setField(member1, "id", 1L)
        ReflectionTestUtils.setField(member2, "id", 2L)
        ReflectionTestUtils.setField(member3, "id", 3L)
        val loginMember = LoginMember(id = 1L, name = "Alice")

        val dutyType1 = DutyType("Work", 0, team, "#ffb3ba")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        val dutyTypes = listOf(dutyType1)

        val dutyDate = LocalDate.of(2025, 3, 12)
        val duty1 = Duty(dutyDate = dutyDate, dutyType = dutyType1, member = member1)
        val duty2 = Duty(dutyDate = dutyDate, dutyType = null, member = member2)
        ReflectionTestUtils.setField(duty1, "id", 1L)
        ReflectionTestUtils.setField(duty2, "id", 2L)

        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2, member3))
        `when`(dutyResolver.resolve(listOf(member1, member2, member3), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, null, DutySource.OVERRIDE),
                3L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        // When
        val shifts = service.loadShift(loginMember, dutyDate)

        // Then
        assertThat(shifts.size).isEqualTo(2) // OFF + Work

        // OFF group should contain member2 (null dutyType) and member3 (no duty record)
        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(2)
        assertThat(offGroup.members.map { it.name }).containsExactlyInAnyOrder("Bob", "Charlie")

        // Work group should contain member1
        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members.size).isEqualTo(1)
        assertThat(workGroup.members.first().name).isEqualTo("Alice")
    }

    @Test
    fun `loadShift should put all members in OFF group when no one has duty`() {
        // Given
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        val member1 = Member(name = "Alice")
        val member2 = Member(name = "Bob")
        member1.team = team
        member2.team = team
        ReflectionTestUtils.setField(member1, "id", 1L)
        ReflectionTestUtils.setField(member2, "id", 2L)
        val loginMember = LoginMember(id = 1L, name = "Alice")

        val dutyType1 = DutyType("Work", 0, team, "#ffb3ba")
        ReflectionTestUtils.setField(dutyType1, "id", 1L)
        val dutyTypes = listOf(dutyType1)

        val dutyDate = LocalDate.of(2025, 3, 12)
        // No duty records for anyone

        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
                2L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        // When
        val shifts = service.loadShift(loginMember, dutyDate)

        // Then
        assertThat(shifts.size).isEqualTo(2) // OFF + Work

        // OFF group should contain both members
        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(2)
        assertThat(offGroup.members.map { it.name }).containsExactlyInAnyOrder("Alice", "Bob")

        // Work group should be empty
        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members).isEmpty()
    }

}
