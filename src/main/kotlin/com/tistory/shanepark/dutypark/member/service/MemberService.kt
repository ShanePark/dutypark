package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.dto.MemberCreateDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
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
) {

    @Transactional(readOnly = true)
    fun findAll(): MutableList<MemberDto> {
        return memberRepository.findAll()
            .sortedWith(compareBy({ it.department?.name }, { it.name }))
            .map { MemberDto.of(it) }
            .toMutableList()
    }

    @Transactional(readOnly = true)
    fun findById(memberId: Long): MemberDto {
        val member = memberRepository.findById(memberId).orElseThrow()
        return MemberDto.of(member)
    }

    fun createMember(memberCreteDto: MemberCreateDto): Member {
        val password = passwordEncoder.encode(memberCreteDto.password)
        val member = Member(
            email = memberCreteDto.email,
            name = memberCreteDto.name,
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
    fun searchMembers(
        page: Pageable, name: String
    ): Page<MemberDto> {
        memberRepository.findMembersByNameContainingIgnoreCase(name, page).let { it ->
            return it.map { MemberDto.of(it) }
        }
    }

    fun updateCalendarVisibility(loginMember: LoginMember, visibility: Visibility) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        member.calendarVisibility = visibility
    }

}
