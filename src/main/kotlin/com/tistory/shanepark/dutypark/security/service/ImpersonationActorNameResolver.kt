package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Propagation
import org.springframework.transaction.annotation.Transactional

@Service
class ImpersonationActorNameResolver(
    private val memberRepository: MemberRepository,
) {
    @Transactional(propagation = Propagation.NOT_SUPPORTED, readOnly = true)
    fun findName(memberId: Long): String? = memberRepository.findById(memberId).orElse(null)?.name
}
