package com.tistory.shanepark.dutypark.team.service

import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.service.DutyPatternService
import com.tistory.shanepark.dutypark.duty.service.DutyResolver
import com.tistory.shanepark.dutypark.duty.service.ResolvedDuty
import com.tistory.shanepark.dutypark.duty.domain.dto.DutySource
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.publiccontent.service.PublicContentService
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
import org.mockito.kotlin.doThrow
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
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
    lateinit var publicContentService: PublicContentService

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
    fun `change team admin rejects member outside team`() {
        val team = Team("Test Team")
        val outsider = Member(name = "outsider")
        ReflectionTestUtils.setField(team, "id", 1L)
        ReflectionTestUtils.setField(outsider, "id", 3L)
        whenever(teamRepository.findById(1L)).thenReturn(Optional.of(team))
        whenever(memberRepository.findById(3L)).thenReturn(Optional.of(outsider))

        val exception = assertThrows<BadRequestException> {
            service.changeTeamAdmin(teamId = 1L, memberId = 3L)
        }

        assertThat(exception.message).isEqualTo("team.member.notInTeam")
        assertThat(team.admin).isNull()
    }

    @Test
    fun `loadShift should return empty shift if member is not in any team`() {
        val longinMember = LoginMember(id = 1L, name = "test")
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(Member(name = "test")))

        val shifts = service.loadShift(loginMember = longinMember, LocalDate.of(2025, 3, 12))

        assertThat(shifts).isEmpty()
    }

    @Test
    fun `updateDefaultDuty validates the new name before updating`() {
        val team = Team("Test Team")
        ReflectionTestUtils.setField(team, "id", 1L)
        `when`(teamRepository.findById(team.id!!)).thenReturn(Optional.of(team))

        service.updateDefaultDuty(team.id!!, "New default", "#123456")

        verify(publicContentService).validateContent("New default")
        assertThat(team.defaultDutyName).isEqualTo("New default")
        assertThat(team.defaultDutyColor).isEqualTo("#123456")
    }

    @Test
    fun `updateDefaultDuty does not mutate when the new name is banned`() {
        val team = Team("Test Team")
        ReflectionTestUtils.setField(team, "id", 1L)
        team.defaultDutyName = "Before"
        team.defaultDutyColor = "#abcdef"
        `when`(teamRepository.findById(team.id!!)).thenReturn(Optional.of(team))
        doThrow(BadRequestException("contentFilter.blocked"))
            .whenever(publicContentService)
            .validateContent("blocked")

        assertThrows<BadRequestException> {
            service.updateDefaultDuty(team.id!!, "blocked", "#123456")
        }

        assertThat(team.defaultDutyName).isEqualTo("Before")
        assertThat(team.defaultDutyColor).isEqualTo("#abcdef")
        verify(publicContentService).validateContent("blocked")
    }

    @Test
    fun `loadShift should return correct shifts when members have duties`() {

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
        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, dutyType2, DutySource.OVERRIDE),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        val shifts = service.loadShift(loginMember, dutyDate)

        assertThat(shifts.size).isEqualTo(3)
        assertThat(shifts[0].members.size).isEqualTo(0)

        assertThat(shifts[1].members.size).isEqualTo(1)
        assertThat(shifts[1].members.first().id).isEqualTo(1L)

        assertThat(shifts[2].members.size).isEqualTo(1)
        assertThat(shifts[2].members.first().id).isEqualTo(2L)
    }

    @Test
    fun `loadShift keeps a hidden type visible when a resolved historical duty uses it`() {
        val team = Team("Test Team")
        ReflectionTestUtils.setField(team, "id", 1L)
        val member = Member(name = "Alice").also {
            it.team = team
            ReflectionTestUtils.setField(it, "id", 1L)
        }
        val hiddenType = DutyType("Legacy", 0, team, "#ffb3ba", hidden = true).also {
            ReflectionTestUtils.setField(it, "id", 10L)
        }
        val dutyDate = LocalDate.of(2025, 3, 12)
        val loginMember = LoginMember(id = 1L, name = "Alice")

        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member))
        `when`(dutyResolver.resolve(listOf(member), dutyDate)).thenReturn(
            mapOf(1L to ResolvedDuty(dutyDate, hiddenType, DutySource.OVERRIDE))
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(listOf(hiddenType))

        val shifts = service.loadShift(loginMember, dutyDate)

        val hiddenShift = shifts.single { it.dutyType.id == hiddenType.id }
        assertThat(hiddenShift.dutyType.hidden).isTrue()
        assertThat(hiddenShift.members.map { it.name }).containsExactly("Alice")
    }

    @Test
    fun `loadShift should include members without duty record in OFF group`() {
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
        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        val shifts = service.loadShift(loginMember, dutyDate)

        assertThat(shifts.size).isEqualTo(2)

        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(1)
        assertThat(offGroup.members.first().name).isEqualTo("Bob")

        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members.size).isEqualTo(1)
        assertThat(workGroup.members.first().name).isEqualTo("Alice")
    }

    @Test
    fun `loadShift should include members with null dutyType in OFF group`() {
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
        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, dutyType1, DutySource.OVERRIDE),
                2L to ResolvedDuty(dutyDate, null, DutySource.OVERRIDE),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        val shifts = service.loadShift(loginMember, dutyDate)

        assertThat(shifts.size).isEqualTo(2)

        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(1)
        assertThat(offGroup.members.first().name).isEqualTo("Bob")

        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members.size).isEqualTo(1)
        assertThat(workGroup.members.first().name).isEqualTo("Alice")
    }

    @Test
    fun `loadShift should handle mixed scenario with work, null dutyType, and no duty record`() {
        val team = Team("Test Team")
        val teamId = 1L
        ReflectionTestUtils.setField(team, "id", teamId)

        val member1 = Member(name = "Alice")
        val member2 = Member(name = "Bob")
        val member3 = Member(name = "Charlie")
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

        val shifts = service.loadShift(loginMember, dutyDate)

        assertThat(shifts.size).isEqualTo(2)

        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(2)
        assertThat(offGroup.members.map { it.name }).containsExactlyInAnyOrder("Bob", "Charlie")

        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members.size).isEqualTo(1)
        assertThat(workGroup.members.first().name).isEqualTo("Alice")
    }

    @Test
    fun `loadShift should put all members in OFF group when no one has duty`() {
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
        `when`(memberRepository.findMembersByTeam(team)).thenReturn(listOf(member1, member2))
        `when`(dutyResolver.resolve(listOf(member1, member2), dutyDate)).thenReturn(
            mapOf(
                1L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
                2L to ResolvedDuty(dutyDate, null, DutySource.DEFAULT_OFF),
            )
        )
        `when`(dutyTypeRepository.findAllByTeam(team)).thenReturn(dutyTypes)
        `when`(memberRepository.findById(1L)).thenReturn(Optional.of(member1))

        val shifts = service.loadShift(loginMember, dutyDate)

        assertThat(shifts.size).isEqualTo(2)

        val offGroup = shifts.find { it.dutyType.id == null }
        assertThat(offGroup).isNotNull
        assertThat(offGroup!!.members.size).isEqualTo(2)
        assertThat(offGroup.members.map { it.name }).containsExactlyInAnyOrder("Alice", "Bob")

        val workGroup = shifts.find { it.dutyType.id == 1L }
        assertThat(workGroup).isNotNull
        assertThat(workGroup!!.members).isEmpty()
    }

}
