package com.tistory.shanepark.dutypark.security.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.RefreshTokenService
import com.tistory.shanepark.dutypark.security.config.JwtConfig
import com.tistory.shanepark.dutypark.security.domain.dto.LoginDto
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.PasswordChangeDto
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.domain.enums.TokenStatus
import jakarta.servlet.http.HttpServletRequest
import org.springframework.http.HttpHeaders
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
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun validateToken(token: String): TokenStatus {
        return jwtProvider.validateToken(token)
    }

    @Transactional(readOnly = true)
    fun tokenToLoginMember(token: String): LoginMember {
        if (validateToken(token) == TokenStatus.VALID) {
            return jwtProvider.parseToken(token)
        }
        throw AuthException()
    }

    fun changePassword(param: PasswordChangeDto, byAdmin: Boolean = false) {
        val member = memberRepository.findById(param.memberId).orElseThrow {
            log.info("change password failed. member not exist:${param.memberId}")
            throw AuthException("존재하지 않는 회원입니다.")
        }

        if (!byAdmin) {
            val passwordMatch = passwordEncoder.matches(param.currentPassword, member.password)
            if (!passwordMatch) {
                log.info("change password failed. password not match:${param.memberId}")
                throw AuthException("비밀번호가 일치하지 않습니다.")
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

    fun getTokenResponse(login: LoginDto, req: HttpServletRequest): TokenResponse {
        val member = memberRepository.findByEmail(login.email).orElseThrow {
            log.info("Login failed. email not exist:${login.email}")
            AuthException("존재하지 않는 계정입니다.")
        }

        if (!passwordEncoder.matches(login.password, member.password)) {
            log.info("Login failed. password not match:${login.email}")
            throw AuthException("비밀번호가 일치하지 않습니다.")
        }

        val jwt = jwtProvider.createToken(member)
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = member.id!!,
            remoteAddr = req.remoteAddr,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )

        log.info("Login Success (Bearer): ${member.name}")

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    fun refreshAccessToken(refreshTokenValue: String, req: HttpServletRequest): TokenResponse {
        val refreshToken = refreshTokenService.findByToken(refreshTokenValue)
            ?: throw AuthException("Invalid refresh token")

        if (!refreshToken.isValid()) {
            throw AuthException("Refresh token expired")
        }

        val member = refreshToken.member
        val newJwt = jwtProvider.createToken(member)

        refreshToken.slideValidUntil(
            req.remoteAddr,
            req.getHeader(HttpHeaders.USER_AGENT),
            jwtConfig.refreshTokenValidityInDays
        )

        log.info("Token refresh succeed. member:${member}")

        return TokenResponse(
            accessToken = newJwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

    fun getTokenResponseByMemberId(memberId: Long, req: HttpServletRequest): TokenResponse {
        val member = memberRepository.findById(memberId).orElseThrow {
            log.info("Token generation failed. member not exist:${memberId}")
            AuthException("존재하지 않는 계정입니다.")
        }

        val jwt = jwtProvider.createToken(member)
        val refreshToken = refreshTokenService.createRefreshToken(
            memberId = memberId,
            remoteAddr = req.remoteAddr,
            userAgent = req.getHeader(HttpHeaders.USER_AGENT)
        )

        log.info("OAuth Login Success (Bearer): ${member.name}")

        return TokenResponse(
            accessToken = jwt,
            refreshToken = refreshToken.token,
            expiresIn = jwtConfig.tokenValidityInSeconds
        )
    }

}
