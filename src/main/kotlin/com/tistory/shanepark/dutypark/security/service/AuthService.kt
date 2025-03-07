package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import jakarta.servlet.http.Cookie
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpHeaders
import org.springframework.http.HttpHeaders.USER_AGENT
import org.springframework.http.ResponseCookie
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class AuthService(
    private val memberRepository: MemberRepository,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val passwordEncoder: PasswordEncoder,
    private val refreshTokenService: RefreshTokenService,
    private val jwtProvider: JwtProvider,
    private val jwtConfig: JwtConfig,
    @Value("\${server.ssl.enabled}") private val isSecure: Boolean
) {
    private val log = logger()

    fun getLoginCookieHeaders(login: LoginDto, req: HttpServletRequest, referer: String): HttpHeaders {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            log.info("Login failed. email not exist:${login.email}")
            DutyparkAuthException()
        }

        if (!passwordEncoder.matches(login.password, member.password)) {
            log.info("Login failed. password not match:${login.email}")
            throw DutyparkAuthException()
        }

        return getLoginCookieHeaders(
            memberId = member.id,
            req = req,
            rememberMe = login.rememberMe,
            rememberMeEmail = login.email
        )
    }

    fun getLoginCookieHeaders(
        memberId: Long?,
        req: HttpServletRequest,
        rememberMe: Boolean = false,
        rememberMeEmail: String? = null
    ): HttpHeaders {
        val member = memberRepository.findById(memberId!!).orElseThrow {
            log.info("Login failed. member not exist:${memberId}")
            throw DutyparkAuthException()
        }

        val jwt = jwtProvider.createToken(member)

        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = memberId,
            remoteAddr = req.remoteAddr,
            userAgent = req.getHeader(USER_AGENT)
        )

        val jwtCookie = ResponseCookie.from(jwtConfig.cookieName, jwt)
            .httpOnly(true)
            .path("/")
            .secure(isSecure)
            .maxAge(jwtConfig.tokenValidityInSeconds)
            .build()

        val refToken = ResponseCookie.from(RefreshToken.cookieName, refreshToken.token)
            .httpOnly(true)
            .path("/")
            .secure(isSecure)
            .maxAge(jwtConfig.refreshTokenValidityInDays * 24 * 60 * 60)
            .build()

        val rememberMeCookieAge = if (rememberMe) 3600 * 24 * 365L else 0L
        val rememberMeCookie = ResponseCookie
            .from("rememberMe", if (rememberMe) rememberMeEmail ?: "" else "")
            .httpOnly(true)
            .path("/")
            .maxAge(rememberMeCookieAge)
            .build()

        log.info("Login Success: ${member.name}")

        val httpHeaders = HttpHeaders()
        httpHeaders.add(HttpHeaders.SET_COOKIE, jwtCookie.toString())
        httpHeaders.add(HttpHeaders.SET_COOKIE, refToken.toString())
        httpHeaders.add(HttpHeaders.SET_COOKIE, rememberMeCookie.toString())

        return httpHeaders
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

    fun changePassword(param: PasswordChangeDto, byAdmin: Boolean = false) {
        val member = memberRepository.findById(param.memberId).orElseThrow {
            log.info("change password failed. member not exist:${param.memberId}")
            throw DutyparkAuthException("존재하지 않는 회원입니다.")
        }

        if (!byAdmin) {
            val passwordMatch = passwordEncoder.matches(param.currentPassword, member.password)
            if (!passwordMatch) {
                log.info("change password failed. password not match:${param.memberId}")
                throw DutyparkAuthException("비밀번호가 일치하지 않습니다.")
            }
        }

        member.password = passwordEncoder.encode(param.newPassword)
        refreshTokenService.revokeAllRefreshTokensByMember(member)

        log.info("Member password changed. member:${param.memberId}")
    }

    fun validateSsoRegister(uuid: String) {
        val memberSsoRegister = memberSsoRegisterRepository.findByUuid(uuid).orElseThrow()
        if (!memberSsoRegister.isValid()) {
            throw IllegalArgumentException("만료된 요청 입니다.")
        }
    }

}
