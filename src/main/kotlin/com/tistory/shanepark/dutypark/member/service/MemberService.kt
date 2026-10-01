package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditChangeAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.duty.batch.domain.DutyBatchTemplate
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberInviteCandidateDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberPreviewDto
import com.tistory.shanepark.dutypark.member.domain.dto.toMemberInviteCandidateDto
import com.tistory.shanepark.dutypark.member.domain.dto.toMemberPreviewDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberManager
import com.tistory.shanepark.dutypark.member.domain.enums.ManagerRole
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import org.springframework.data.domain.Page
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class MemberService(
    private val memberRepository: MemberRepository,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val memberManagerRepository: MemberManagerRepository,
    private val memberSocialAccountService: MemberSocialAccountService,
    private val memberDtoAssembler: MemberDtoAssembler,
) {

    private val log = logger()

    @Transactional(readOnly = true)
    fun findById(memberId: Long): MemberDto {
        val member = memberRepository.findById(memberId).orElseThrow()
        return memberDtoAssembler.toDto(member)
    }

    @Transactional(readOnly = true)
    fun findPreviewById(memberId: Long): MemberPreviewDto {
        val member = memberRepository.findById(memberId).orElseThrow()
        return member.toMemberPreviewDto()
    }

    fun createSsoMember(username: String, memberSsoRegisterUUID: String): Member {
        val ssoRegister = memberSsoRegisterRepository.findByUuid(memberSsoRegisterUUID).orElseThrow {
            log.warn("Signup denied {}", auditContext(mapOf("event" to "member.signup.denied", "reason" to "registration_not_found")))
            NoSuchElementException("No value present")
        }
        if (!ssoRegister.isValid()) {
            log.warn("Signup denied {}", auditContext(mapOf("event" to "member.signup.denied", "provider" to ssoRegister.ssoType, "reason" to "registration_expired")))
            throw IllegalArgumentException("sso.uuid.invalid")
        }
        val member = Member(
            name = username,
            password = ""
        )
        memberRepository.save(member)
        memberSocialAccountService.link(member, ssoRegister.ssoType, ssoRegister.ssoId)
        log.auditEventAfterCommit(
            event = "member.signup.completed", actor = member.toAuditActor(),
            target = mapOf("memberId" to member.id), details = mapOf("provider" to ssoRegister.ssoType),
        )
        return member
    }

    @Transactional(readOnly = true)
    fun searchMembersToInviteTeam(
        page: Pageable, keyword: String, loginMemberId: Long
    ): Page<MemberInviteCandidateDto> {
        val membersPage = memberRepository.searchMembersToInviteTeam(keyword, loginMemberId, page)
        return membersPage.map { it.toMemberInviteCandidateDto() }
    }

    fun updateCalendarVisibility(loginMember: LoginMember, visibility: Visibility) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val previous = member.calendarVisibility
        member.calendarVisibility = visibility
        log.auditChangeAfterCommit(
            event = "member.calendar_visibility.changed", actor = loginMember.toAuditActor(),
            target = mapOf("memberId" to member.id),
            before = mapOf("visibility" to previous), after = mapOf("visibility" to visibility),
        )
    }

    fun getDutyBatchTemplate(memberId: Long): DutyBatchTemplate? {
        val member = memberRepository.findById(memberId).orElseThrow()
        return member.team?.dutyBatchTemplate
    }

    fun assignManager(managerId: Long, managedId: Long, actor: LoginMember? = null) {
        val manager = memberRepository.findById(managerId).orElseThrow()
        val managed = memberRepository.findById(managedId).orElseThrow()

        if (isManager(manager, managed)) {
            throw IllegalArgumentException("Already assigned as manager, managerId: $managerId, managedId: $managedId")
        }

        val entity = MemberManager(manager = manager, managed = managed, role = ManagerRole.MANAGER)
        memberManagerRepository.save(entity)
        log.auditEventAfterCommit(
            event = "member.manager.assigned", actor = actor?.toAuditActor() ?: managed.toAuditActor(),
            target = mapOf("managedMemberId" to managedId, "managerId" to managerId),
            details = mapOf("role" to ManagerRole.MANAGER),
        )
    }

    fun unassignManager(managerId: Long, managedId: Long, actor: LoginMember? = null) {
        val manager = memberRepository.findById(managerId).orElseThrow()
        val managed = memberRepository.findById(managedId).orElseThrow()
        if (!isManager(manager, managed)) {
            throw IllegalArgumentException("Not assigned as manager, managerId: $managerId, managedId: $managedId")
        }
        memberManagerRepository.findAllByManagerAndManaged(manager = manager, managed = managed)
            .forEach { memberManagerRepository.delete(it) }
        log.auditEventAfterCommit(
            event = "member.manager.unassigned", actor = actor?.toAuditActor() ?: managed.toAuditActor(),
            target = mapOf("managedMemberId" to managedId, "managerId" to managerId),
        )
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
        return memberDtoAssembler.toDtos(findAllManagers(member))
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
        return memberDtoAssembler.toDtos(managedMembers)
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

        log.auditEventAfterCommit(
            event = "member.auxiliary.created", actor = loginMember.toAuditActor(),
            target = mapOf("memberId" to member.id), details = mapOf("managerId" to parentMember.id),
        )
        return memberDtoAssembler.toDto(member)
    }

}
