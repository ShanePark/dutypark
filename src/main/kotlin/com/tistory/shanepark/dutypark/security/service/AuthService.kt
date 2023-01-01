package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.InvalidAuthenticationException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.entity.LoginSession
import jakarta.transaction.Transactional
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service

@Service
@Transactional
class AuthService(
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder
) {

    fun authenticate(login: LoginDto): LoginSession {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            InvalidAuthenticationException()
        }
        if (!passwordEncoder.matches(login.password, member.password)) {
            throw InvalidAuthenticationException()
        }

        return member.addSession()
    }

}
