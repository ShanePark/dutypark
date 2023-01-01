package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class MemberService(
    private val memberRepository: MemberRepository,
) {

    fun findAll(): MutableList<MemberDto> {
        return memberRepository.findAll().map { MemberDto(it) }.toMutableList()
    }

    fun findMemberByName(name: String): Member {
        return memberRepository.findMemberByName(name)
            ?: throw NoSuchElementException("Member not found:$name")
    }


    fun findById(memberId: Long): Member {
        return memberRepository.findById(memberId).orElseThrow()
    }
}
