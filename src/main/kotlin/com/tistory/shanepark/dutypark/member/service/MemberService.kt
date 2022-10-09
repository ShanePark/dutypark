package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.Member
import com.tistory.shanepark.dutypark.member.dto.MemberDto
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.stereotype.Service

@Service
class MemberService(
    val memberRepository: MemberRepository,
) {
    fun findAll(): MutableList<MemberDto> {
        return memberRepository.findAll().map { MemberDto(it) }.toMutableList()
    }

    fun findMemberByName(name: String): Member {
        return memberRepository.findMemberByName(name)
            ?: throw NoSuchElementException("Member not found:$name")
    }
}
