package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.http.HttpHeaders.USER_AGENT
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class AuthService(
    private val memberRepository: MemberRepository,
    private val passwordEncoder: PasswordEncoder,
    private val refreshTokenService: RefreshTokenService,
    private val jwtProvider: JwtProvider,
) {
    val log: Logger = LoggerFactory.getLogger(AuthService::class.java)

    @Transactional(readOnly = true)
    fun login(login: LoginDto): LoginMember {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            log.info("Login failed. email not exist:${login.email}")
            DutyparkAuthException()
        }

        if (!passwordEncoder.matches(login.password, member.password)) {
            log.info("Login failed. password not match:${login.email}")
            throw DutyparkAuthException()
        }

        val jwt = jwtProvider.createToken(member)
        return tokenToLoginMember(jwt)
    }

    @Transactional(readOnly = true)
    fun validateToken(token: String): TokenStatus {
        return jwtProvider.validateToken(token)
    }

    @Transactional(readOnly = true)
    fun tokenToLoginMember(token: String): LoginMember {
        if (validateToken(token) == TokenStatus.VALID) {
            return jwtProvider.parseToken(token)
        }
        throw DutyparkAuthException()
    }

    fun tokenRefresh(refreshToken: String, request: HttpServletRequest, response: HttpServletResponse): String? {
        refreshTokenService.findByToken(refreshToken)?.let {
            if (it.isValid()) {
                slideRefreshToken(request = request, response = response, refreshToken = it)
                log.info("refresh token succeed. member:${it.member.email}, remoteAddr:${request.remoteAddr}")
                return jwtProvider.createToken(it.member)
            }
        }
        return null
    }

    private fun slideRefreshToken(
        request: HttpServletRequest,
        response: HttpServletResponse,
        refreshToken: RefreshToken
    ) {
        val remoteAddr: String? = request.remoteAddr
        val userAgent: String? = request.getHeader(USER_AGENT)
        refreshToken.slideValidUntil(remoteAddr, userAgent)
        val cookie: Cookie = refreshToken.createCookie()
        response.addCookie(cookie)
    }

}
