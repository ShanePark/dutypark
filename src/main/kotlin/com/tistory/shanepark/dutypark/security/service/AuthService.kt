package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.LoginSessionResponse
import com.tistory.shanepark.dutypark.security.domain.entity.LoginSession
import com.tistory.shanepark.dutypark.security.repository.LoginSessionRepository
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class AuthService(
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val sessionRepository: LoginSessionRepository
) {

    @Transactional
    fun authenticate(login: LoginDto): LoginSessionResponse {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            AuthenticationException()
        }
        if (!passwordEncoder.matches(login.password, member.password)) {
            throw AuthenticationException()
        }

        val session = member.addSession()
        return LoginSessionResponse(session.accessToken)
    }

    fun findLoginMemberByToken(token: String): LoginMember {
        sessionRepository.findByAccessToken(token)?.let {
            val member = it.member
            return LoginMember(member.id!!, member.email, member.name)
        } ?: throw AuthenticationException()
    }

}
