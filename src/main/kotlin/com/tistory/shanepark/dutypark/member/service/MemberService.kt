package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.member.domain.dto.MemberCreateDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class MemberService(
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val memberManagerRepository: MemberManagerRepository,
) {

    @Transactional(readOnly = true)
    fun findAll(): List<MemberDto> {
        return memberRepository.findAll()
            .sortedWith(compareBy({ it.team?.name }, { it.name }))
            .map { MemberDto.of(it) }
    }

    @Transactional(readOnly = true)
    fun findById(memberId: Long): MemberDto {
        val member = memberRepository.findById(memberId).orElseThrow()
        return MemberDto.of(member)
    }

    fun createMember(memberCreateDto: MemberCreateDto): Member {
        val password = passwordEncoder.encode(memberCreateDto.password)
        val member = Member(
            email = memberCreateDto.email,
            name = memberCreateDto.name,
            password = password
        )
        return memberRepository.save(member)
    }

    fun createSsoMember(username: String, memberSsoRegisterUUID: String): Member {
        val ssoRegister = memberSsoRegisterRepository.findByUuid(memberSsoRegisterUUID).orElseThrow()
        if (!ssoRegister.isValid()) {
            throw IllegalArgumentException("Invalid SSO Register")
        }
        val member = Member(
            name = username,
            password = ""
        )
        memberRepository.save(member)
        when (ssoRegister.ssoType) {
            SsoType.KAKAO -> {
                member.kakaoId = ssoRegister.ssoId
            }

            SsoType.NAVER -> {
                // not implemented yet
//                member.naverId = ssoRegister.ssoId
            }
        }
        return member
    }

    @Transactional(readOnly = true)
    fun searchMembersToInviteTeam(
        page: Pageable, keyword: String
    ): Page<MemberDto> {
        memberRepository.findMembersByNameContainingIgnoreCaseAndTeamIsNull(keyword, page).let { it ->
            return it.map { MemberDto.of(it) }
        }
    }

    fun updateCalendarVisibility(loginMember: LoginMember, visibility: Visibility) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        member.calendarVisibility = visibility
    }

    fun getDutyBatchTemplate(memberId: Long): DutyBatchTemplate? {
        val member = memberRepository.findById(memberId).orElseThrow()
        return member.team?.dutyBatchTemplate
    }

    fun assignManager(managerId: Long, managedId: Long) {
        val manager = memberRepository.findById(managerId).orElseThrow()
        val managed = memberRepository.findById(managedId).orElseThrow()

        if (isManager(manager, managed)) {
            throw IllegalArgumentException("Already assigned as manager, managerId: $managerId, managedId: $managedId")
        }

        val entity = MemberManager(manager = manager, managed = managed, role = ManagerRole.MANAGER)
        memberManagerRepository.save(entity)
    }

    fun unassignManager(managerId: Long, managedId: Long) {
        val manager = memberRepository.findById(managerId).orElseThrow()
        val managed = memberRepository.findById(managedId).orElseThrow()
        if (!isManager(manager, managed)) {
            throw IllegalArgumentException("Not assigned as manager, managerId: $managerId, managedId: $managedId")
        }
        memberManagerRepository.findAllByManagerAndManaged(manager = manager, managed = managed)
            .forEach { memberManagerRepository.delete(it) }
    }

    fun canManageTeam(loginMember: LoginMember, team: Team?): Boolean {
        if (team == null) {
            return false
        }
        if (isTeamAdmin(loginMember = loginMember, team = team)) {
            return true
        }
        return team.isManager(loginMember)
    }

    private fun isTeamAdmin(loginMember: LoginMember, team: Team): Boolean {
        return team.admin?.id == loginMember.id
    }

    fun isManager(isManager: LoginMember, target: Member): Boolean {
        val member = memberRepository.findById(isManager.id).orElseThrow()
        return isManager(member, target)
    }

    fun isManager(manager: Member, target: Member): Boolean {
        return memberManagerRepository.findAllByManagerAndManaged(manager, target).isNotEmpty()
    }

    private fun findAllManagers(member: Member): List<Member> {
        return memberManagerRepository.findAllByManaged(member)
            .map { it.manager }
    }

    fun findAllManagers(loginMember: LoginMember): List<MemberDto> {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        return findAllManagers(member).map { MemberDto.of(it) }
    }

    fun isManager(isManager: LoginMember, targetMemberId: Long): Boolean {
        val target = memberRepository.findById(targetMemberId).orElseThrow()
        return isManager(isManager = isManager, target = target)
    }

    @Transactional(readOnly = true)
    fun findManagedMemberIds(loginMember: LoginMember): Set<Long> {
        val manager = memberRepository.findById(loginMember.id).orElseThrow()
        return memberManagerRepository.findAllByManager(manager)
            .mapNotNull { it.managed.id }
            .toSet()
    }

    @Transactional(readOnly = true)
    fun findManagedMembers(loginMember: LoginMember): List<MemberDto> {
        val manager = memberRepository.findById(loginMember.id).orElseThrow()
        val managedMembers = memberManagerRepository.findAllByManager(manager).map { it.managed }
        return managedMembers.map { MemberDto.of(it) }
    }

    fun createAuxiliaryAccount(loginMember: LoginMember, name: String): MemberDto {
        val member = Member(
            name = name,
            email = null,
            password = null
        )
        memberRepository.save(member)

        val parentMember = memberRepository.findById(loginMember.id).orElseThrow()
        val managerEntity = MemberManager(
            manager = parentMember,
            managed = member,
            role = ManagerRole.MANAGER
        )
        memberManagerRepository.save(managerEntity)

        return MemberDto.of(member)
    }

}
