package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import com.tistory.shanepark.dutypark.security.repository.RefreshTokenRepository
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime

@Service
@Transactional
class AuthService(
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val jwtProvider: JwtProvider,
    @Value("\${jwt.refresh-token-validity-in-days}") val refreshTokenValidDays: Long
) {

    val log: Logger = LoggerFactory.getLogger(AuthService::class.java)

    fun login(login: LoginDto): String {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            AuthenticationException()
        }
        if (!passwordEncoder.matches(login.password, member.password)) {
            throw AuthenticationException()
        }

        return jwtProvider.createToken(member)
    }

    fun validateToken(token: String): TokenStatus {
        return jwtProvider.validateToken(token)
    }

    fun tokenToLoginMember(token: String): LoginMember? {
        if (validateToken(token) == TokenStatus.VALID) {
            return jwtProvider.parseToken(token)
        }
        return null
    }

    fun refreshToken(refreshToken: String): String? {
        refreshTokenRepository.findByToken(refreshToken)?.let {
            if (it.validUntil.isAfter(LocalDateTime.now())) {
                it.slideValidUntil()
                return jwtProvider.createToken(it.member)
            }
        }
        return null
    }

    fun createRefreshToken(loginDto: LoginDto): String {
        memberRepository.findByEmail(loginDto.email).orElseThrow {
            AuthenticationException()
        }.let {
            val refreshToken = RefreshToken(it, LocalDateTime.now().plusDays(refreshTokenValidDays))
            refreshTokenRepository.save(refreshToken)
            return refreshToken.token
        }
    }

}
