package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.PageRequest
import org.springframework.data.domain.Sort
import java.time.LocalDateTime

class MemberServiceTest : DutyparkIntegrationTest() {

    @Test
    fun `Search member`() {
        // Given
        memberRepository.deleteAll()
        val member1 = memberRepository.save(Member("shane", "shane_email", "pass"))
        memberRepository.save(Member("jenny", "jenny_email", "pass"))
        val member3 = memberRepository.save(Member("john", "john_email", "pass"))
        memberRepository.save(Member("jane", "jane_email", "pass"))
        memberRepository.save(Member("james", "james_email", "pass"))
        memberRepository.save(Member("홍길동", "hong_email", "pass"))
        memberRepository.save(Member("김길동", "kim_email", "pass"))
        memberRepository.save(Member("박단비", "park_email", "pass"))
        memberRepository.save(Member("이단비", "lee_email", "pass"))
        memberRepository.save(Member("전이재", "jeon_email", "pass"))
        memberRepository.save(Member("민주아", "min_email", "pass"))
        memberRepository.save(Member("김민주", "kim2_email", "pass"))

        // When
        val sort = Sort.by("name").ascending()
        val page = PageRequest.of(0, 10, sort)
        val searchAll = memberService.searchMembersToInviteTeam(page, "")

        // Then
        assertThat(searchAll.totalElements).isEqualTo(12)
        assertThat(searchAll.content).isSortedAccordingTo { o1, o2 -> o1.name.compareTo(o2.name) }
        assertThat(search(page, "j")).hasSize(4)
        assertThat(search(page, "john").content.map { it.id }).containsExactly(member3.id)
        assertThat(search(page, "han").content.map { it.id }).containsExactly(member1.id)
    }

    private fun search(page: PageRequest, name: String) = memberService.searchMembersToInviteTeam(page, name)

    @Test
    fun `update calendar visibility`() {
        // Given
        val member = memberRepository.save(Member("shane", "shane_email", "pass"))
        val loginMember = loginMember(member)

        // When
        memberService.updateCalendarVisibility(loginMember, Visibility.PRIVATE)

        // Then
        val findMember = memberRepository.findById(member.id!!).orElseThrow()
        assertThat(findMember.calendarVisibility).isEqualTo(Visibility.PRIVATE)
    }

    @Test
    fun `create Sso member`(@Autowired memberSsoRegisterRepository: MemberSsoRegisterRepository) {
        // Given
        memberSsoRegisterRepository.deleteAll()
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.KAKAO, "kakao_id"))

        // When
        val member = memberService.createSsoMember("shane", ssoRegister.uuid)

        // Then
        assertThat(member.name).isEqualTo("shane")
        assertThat(member.password).isEqualTo("")
        assertThat(member.kakaoId).isEqualTo("kakao_id")
    }

    @Test
    fun `create Sso member fails when register expired`(@Autowired memberSsoRegisterRepository: MemberSsoRegisterRepository) {
        memberSsoRegisterRepository.deleteAll()
        val ssoRegister = MemberSsoRegister(SsoType.KAKAO, "kakao_id")
        val createdDateField = MemberSsoRegister::class.java.getDeclaredField("createdDate")
        createdDateField.isAccessible = true
        createdDateField.set(ssoRegister, LocalDateTime.now().minusDays(2))
        memberSsoRegisterRepository.save(ssoRegister)

        assertThrows<IllegalArgumentException> {
            memberService.createSsoMember("shane", ssoRegister.uuid)
        }
    }

    @Test
    fun `create Sso member for NAVER does not set kakaoId`(@Autowired memberSsoRegisterRepository: MemberSsoRegisterRepository) {
        memberSsoRegisterRepository.deleteAll()
        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(SsoType.NAVER, "naver_id"))

        val member = memberService.createSsoMember("shane", ssoRegister.uuid)

        assertThat(member.kakaoId).isNull()
    }

    @Test
    fun `assign manager success`() {
        // Given
        val manager = memberRepository.save(Member("shane", "shane_email", "pass"))
        val managed = memberRepository.save(Member("jenny", "jenny_email", "pass"))

        // When
        memberService.assignManager(manager.id!!, managed.id!!)

        // Then
        assertThat(memberService.isManager(manager = manager, target = managed)).isTrue
    }

    @Test
    fun `assign manager fail if already manager`() {
        // Given
        val manager = memberRepository.save(Member("shane", "shane_email", "pass"))
        val managed = memberRepository.save(Member("jenny", "jenny_email", "pass"))
        memberService.assignManager(manager.id!!, managed.id!!)

        // Then
        assertThrows<IllegalArgumentException> {
            memberService.assignManager(manager.id!!, managed.id!!)
        }
    }

    @Test
    fun `unassign manager success`() {
        // Given
        val manager = memberRepository.save(Member("shane", "shane_email", "pass"))
        val managed = memberRepository.save(Member("jenny", "jenny_email", "pass"))
        memberService.assignManager(manager.id!!, managed.id!!)

        // When
        memberService.unassignManager(manager.id!!, managed.id!!)

        // Then
        assertThat(memberService.isManager(manager = manager, target = managed)).isFalse
    }

    @Test
    fun `unassign manager fail if not manager`() {
        // Given
        val manager = memberRepository.save(Member("shane", "shane_email", "pass"))
        val managed = memberRepository.save(Member("jenny", "jenny_email", "pass"))
        memberService.assignManager(managerId = manager.id!!, managedId = managed.id!!)
        memberService.unassignManager(managerId = manager.id!!, managedId = managed.id!!)

        // Then
        assertThrows<IllegalArgumentException> {
            memberService.unassignManager(manager.id!!, managed.id!!)
        }

    }

    @Test
    fun `find All managers`() {
        // Given
        val manager = memberRepository.save(Member("shane", "shane_email", "pass"))
        val managed1 = memberRepository.save(Member("jenny", "jenny_email", "pass"))
        val managed2 = memberRepository.save(Member("john", "john_email", "pass"))
        memberService.assignManager(managerId = manager.id!!, managedId = managed1.id!!)
        memberService.assignManager(managerId = manager.id!!, managedId = managed2.id!!)

        // Then
        assertThat(memberService.findAllManagers(loginMember(managed1))).containsExactly(MemberDto.of(manager))
        assertThat(memberService.findAllManagers(loginMember(managed2))).containsExactly(MemberDto.of(manager))
    }

    @Test
    fun `canManageTeam returns false for null team`() {
        val login = loginMember(TestData.member)

        val result = memberService.canManageTeam(login, null)

        assertThat(result).isFalse
    }

    @Test
    fun `canManageTeam returns true for admin`() {
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val admin = memberRepository.findById(TestData.member.id!!).orElseThrow()
        team.changeAdmin(admin)

        val result = memberService.canManageTeam(loginMember(admin), team)

        assertThat(result).isTrue
    }

    @Test
    fun `canManageTeam returns true for manager`() {
        val team = teamRepository.findById(TestData.team.id!!).orElseThrow()
        val manager = memberRepository.findById(TestData.member.id!!).orElseThrow()
        team.addManager(manager)

        val result = memberService.canManageTeam(loginMember(manager), team)

        assertThat(result).isTrue
    }

    @Test
    fun `createAuxiliaryAccount creates managed member`() {
        val parent = memberRepository.findById(TestData.member.id!!).orElseThrow()
        val result = memberService.createAuxiliaryAccount(loginMember(parent), "aux")

        val created = memberRepository.findById(result.id!!).orElseThrow()
        val managers = memberManagerRepository.findAllByManaged(created)
        assertThat(managers).anyMatch { it.manager.id == parent.id }
    }

}
