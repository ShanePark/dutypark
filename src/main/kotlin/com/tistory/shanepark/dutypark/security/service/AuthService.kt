package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthenticationException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.RefreshTokenDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import com.tistory.shanepark.dutypark.security.repository.RefreshTokenRepository
import jakarta.servlet.http.HttpServletRequest
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.http.HttpHeaders.USER_AGENT
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
    private val jwtConfig: JwtConfig,
) {

    val log: Logger = LoggerFactory.getLogger(AuthService::class.java)


    fun login(login: LoginDto): String {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            log.info("Login failed. email not exist:${login.email}")
            AuthenticationException()
        }
        if (!passwordEncoder.matches(login.password, member.password)) {
            log.info("Login failed. password not match:${login.email}")
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

    fun tokenRefresh(refreshToken: String, request: HttpServletRequest): String? {
        refreshTokenRepository.findByToken(refreshToken)?.let {
            val remoteAddr: String? = request.remoteAddr
            val userAgent: String? = request.getHeader(USER_AGENT)
            if (it.validation(remoteAddr, userAgent)) {
                log.info("refresh token succeed. member:${it.member.email}, remoteAddr:$remoteAddr")
                return jwtProvider.createToken(it.member)
            }
        }
        return null
    }

    fun createRefreshToken(loginDto: LoginDto, request: HttpServletRequest): String {
        memberRepository.findByEmail(loginDto.email).orElseThrow {
            AuthenticationException()
        }.let {
            val refreshToken = RefreshToken(
                member = it,
                validUntil = LocalDateTime.now().plusDays(jwtConfig.refreshTokenValidityInDays),
                remoteAddr = request.remoteAddr,
                userAgent = request.getHeader(USER_AGENT)
            )
            refreshTokenRepository.save(refreshToken)
            return refreshToken.token
        }
    }

    fun findAllRefreshTokens(): List<RefreshTokenDto> {
        return refreshTokenRepository.findAllWithMemberOrderByLastUsedDesc()
            .map { RefreshTokenDto.of(it) }
    }

}
