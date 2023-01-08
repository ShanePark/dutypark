package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class AuthService(
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val jwtProvider: JwtProvider,
) {

    val log: Logger = LoggerFactory.getLogger(AuthService::class.java)

    @Transactional
    fun authenticate(login: LoginDto): String {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            AuthenticationException()
        }
        if (!passwordEncoder.matches(login.password, member.password)) {
            throw AuthenticationException()
        }

        return jwtProvider.createToken(member)
    }

    fun validateToken(token: String): LoginMember {
        if (!jwtProvider.isValidToken(token)) {
            throw AuthenticationException()
        }
        return jwtProvider.parseToken(token)
    }

}
