package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.*
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDateTime
import java.util.*

@ExtendWith(MockitoExtension::class)
class MemberServiceTest {

    private val fixedDateTime = LocalDateTime.of(2025, 1, 15, 12, 0, 0)

    @Mock
    private lateinit var memberRepository: MemberRepository

    @Mock
    private lateinit var passwordEncoder: PasswordEncoder

    @Mock
    private lateinit var memberSsoRegisterRepository: MemberSsoRegisterRepository

    @Mock
    private lateinit var memberManagerRepository: MemberManagerRepository

    private lateinit var memberService: MemberService

    @BeforeEach
    fun setUp() {
        memberService = MemberService(
            memberRepository,
            passwordEncoder,
            memberSsoRegisterRepository,
            memberManagerRepository
        )
    }

    @Test
    fun `update calendar visibility`() {
        // Given
        val member = createMember(1L, "shane", "shane@email.com")
        val loginMember = createLoginMember(member)

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))

        // When
        memberService.updateCalendarVisibility(loginMember, Visibility.PRIVATE)

        // Then
        assertThat(member.calendarVisibility).isEqualTo(Visibility.PRIVATE)
    }

    @Test
    fun `create Sso member`() {
        // Given
        val uuid = UUID.randomUUID().toString()
        val ssoRegister = MemberSsoRegister(SsoType.KAKAO, "kakao_id")
        ReflectionTestUtils.setField(ssoRegister, "uuid", uuid)

        whenever(memberSsoRegisterRepository.findByUuid(uuid)).thenReturn(Optional.of(ssoRegister))
        whenever(memberRepository.save(any<Member>())).thenAnswer { it.arguments[0] }

        // When
        val member = memberService.createSsoMember("shane", uuid)

        // Then
        assertThat(member.name).isEqualTo("shane")
        assertThat(member.password).isEqualTo("")
        assertThat(member.kakaoId).isEqualTo("kakao_id")
        verify(memberRepository).save(any<Member>())
    }

    @Test
    fun `create Sso member fails when register expired`() {
        // Given
        val uuid = UUID.randomUUID().toString()
        val ssoRegister = MemberSsoRegister(SsoType.KAKAO, "kakao_id")
        ReflectionTestUtils.setField(ssoRegister, "uuid", uuid)
        ReflectionTestUtils.setField(ssoRegister, "createdDate", fixedDateTime.minusDays(2))

        whenever(memberSsoRegisterRepository.findByUuid(uuid)).thenReturn(Optional.of(ssoRegister))

        // When & Then
        assertThrows<IllegalArgumentException> {
            memberService.createSsoMember("shane", uuid)
        }
    }

    @Test
    fun `create Sso member for NAVER does not set kakaoId`() {
        // Given
        val uuid = UUID.randomUUID().toString()
        val ssoRegister = MemberSsoRegister(SsoType.NAVER, "naver_id")
        ReflectionTestUtils.setField(ssoRegister, "uuid", uuid)

        whenever(memberSsoRegisterRepository.findByUuid(uuid)).thenReturn(Optional.of(ssoRegister))
        whenever(memberRepository.save(any<Member>())).thenAnswer { it.arguments[0] }

        // When
        val member = memberService.createSsoMember("shane", uuid)

        // Then
        assertThat(member.kakaoId).isNull()
    }

    @Test
    fun `assign manager success`() {
        // Given
        val manager = createMember(1L, "shane", "shane@email.com")
        val managed = createMember(2L, "jenny", "jenny@email.com")

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(2L)).thenReturn(Optional.of(managed))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, managed)).thenReturn(emptyList())
        whenever(memberManagerRepository.save(any<MemberManager>())).thenAnswer { it.arguments[0] }

        // When
        memberService.assignManager(1L, 2L)

        // Then
        verify(memberManagerRepository).save(any<MemberManager>())
    }

    @Test
    fun `assign manager fail if already manager`() {
        // Given
        val manager = createMember(1L, "shane", "shane@email.com")
        val managed = createMember(2L, "jenny", "jenny@email.com")
        val existingRelation = MemberManager(manager, managed, ManagerRole.MANAGER)

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(2L)).thenReturn(Optional.of(managed))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, managed)).thenReturn(listOf(existingRelation))

        // When & Then
        assertThrows<IllegalArgumentException> {
            memberService.assignManager(1L, 2L)
        }
    }

    @Test
    fun `unassign manager success`() {
        // Given
        val manager = createMember(1L, "shane", "shane@email.com")
        val managed = createMember(2L, "jenny", "jenny@email.com")
        val existingRelation = MemberManager(manager, managed, ManagerRole.MANAGER)

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(2L)).thenReturn(Optional.of(managed))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, managed)).thenReturn(listOf(existingRelation))

        // When
        memberService.unassignManager(1L, 2L)

        // Then
        verify(memberManagerRepository).delete(existingRelation)
    }

    @Test
    fun `unassign manager fail if not manager`() {
        // Given
        val manager = createMember(1L, "shane", "shane@email.com")
        val managed = createMember(2L, "jenny", "jenny@email.com")

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(manager))
        whenever(memberRepository.findById(2L)).thenReturn(Optional.of(managed))
        whenever(memberManagerRepository.findAllByManagerAndManaged(manager, managed)).thenReturn(emptyList())

        // When & Then
        assertThrows<IllegalArgumentException> {
            memberService.unassignManager(1L, 2L)
        }
    }

    @Test
    fun `find All managers`() {
        // Given
        val manager = createMember(1L, "shane", "shane@email.com")
        val managed = createMember(2L, "jenny", "jenny@email.com")
        val relation = MemberManager(manager, managed, ManagerRole.MANAGER)

        whenever(memberRepository.findById(2L)).thenReturn(Optional.of(managed))
        whenever(memberManagerRepository.findAllByManaged(managed)).thenReturn(listOf(relation))

        // When
        val loginMember = createLoginMember(managed)
        val managers = memberService.findAllManagers(loginMember)

        // Then
        assertThat(managers).hasSize(1)
        assertThat(managers[0].id).isEqualTo(1L)
        assertThat(managers[0].name).isEqualTo("shane")
    }

    @Test
    fun `canManageTeam returns false for null team`() {
        // Given
        val member = createMember(1L, "shane", "shane@email.com")
        val loginMember = createLoginMember(member)

        // When
        val result = memberService.canManageTeam(loginMember, null)

        // Then
        assertThat(result).isFalse
    }

    @Test
    fun `canManageTeam returns true for admin`() {
        // Given
        val member = createMember(1L, "shane", "shane@email.com")
        val team = Team("testTeam")
        ReflectionTestUtils.setField(team, "id", 1L)
        team.changeAdmin(member)

        val loginMember = createLoginMember(member)

        // When
        val result = memberService.canManageTeam(loginMember, team)

        // Then
        assertThat(result).isTrue
    }

    @Test
    fun `canManageTeam returns true for manager`() {
        // Given
        val member = createMember(1L, "shane", "shane@email.com")
        val team = Team("testTeam")
        ReflectionTestUtils.setField(team, "id", 1L)
        member.team = team
        team.addManager(member)

        val loginMember = createLoginMember(member)

        // When
        val result = memberService.canManageTeam(loginMember, team)

        // Then
        assertThat(result).isTrue
    }

    @Test
    fun `createAuxiliaryAccount creates managed member`() {
        // Given
        val parent = createMember(1L, "parent", "parent@email.com")
        val loginMember = createLoginMember(parent)

        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(parent))
        whenever(memberRepository.save(any<Member>())).thenAnswer { invocation ->
            val savedMember = invocation.arguments[0] as Member
            ReflectionTestUtils.setField(savedMember, "id", 2L)
            savedMember
        }
        whenever(memberManagerRepository.save(any<MemberManager>())).thenAnswer { it.arguments[0] }

        // When
        val result = memberService.createAuxiliaryAccount(loginMember, "aux")

        // Then
        assertThat(result.name).isEqualTo("aux")
        assertThat(result.id).isEqualTo(2L)
        verify(memberManagerRepository).save(argThat<MemberManager> {
            this.manager.id == 1L && this.managed.name == "aux" && this.role == ManagerRole.MANAGER
        })
    }

    private fun createMember(id: Long, name: String, email: String): Member {
        val member = Member(name, email, "password")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }

    private fun createLoginMember(member: Member): LoginMember {
        return LoginMember(
            id = member.id!!,
            email = member.email,
            name = member.name,
            team = member.team?.name,
            isAdmin = false
        )
    }
}
