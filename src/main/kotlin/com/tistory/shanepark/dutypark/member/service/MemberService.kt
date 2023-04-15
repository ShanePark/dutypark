package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.dto.MemberCreateDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
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
) {

    @Transactional(readOnly = true)
    fun findAll(): MutableList<MemberDto> {
        return memberRepository.findAll().map { MemberDto(it) }.toMutableList()
    }

    @Transactional(readOnly = true)
    fun findMemberByName(name: String): Member {
        return memberRepository.findMemberByName(name)
            ?: throw NoSuchElementException("Member not found:$name")
    }

    @Transactional(readOnly = true)
    fun findById(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow()
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

    @Transactional(readOnly = true)
    fun searchMembers(
        page: Pageable, name: String
    ): Page<MemberDto> {
        memberRepository.findMembersByNameContainingIgnoreCase(name, page).let { it ->
            return it.map { MemberDto(it) }
        }
    }
}
