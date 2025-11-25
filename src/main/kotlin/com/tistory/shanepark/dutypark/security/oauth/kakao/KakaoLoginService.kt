package com.tistory.shanepark.dutypark.security.oauth.kakao

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.net.URI
import java.net.URLEncoder
import java.nio.charset.StandardCharsets

@Service
@Transactional
class KakaoLoginService(
    private val kakaoTokenApi: KakaoTokenApi,
    private val kakaoUserInfoApi: KakaoUserInfoApi,
    private val memberRepository: MemberRepository,
    private val authService: AuthService,
    private val MemberSsoRegisterRepository: MemberSsoRegisterRepository,
    @param:Value("\${oauth.kakao.rest-api-key}") private val restApiKey: String
) {
    private val log = logger()

    private fun getKakaoId(redirectUrl: String, code: String): String {
        val kakaoTokenResponse = kakaoTokenApi.getAccessToken(
            grantType = "authorization_code",
            clientId = restApiKey,
            redirectUri = redirectUrl,
            code = code
        )

        val userinfo = kakaoUserInfoApi.getUserInfo(accessToken = "Bearer ${kakaoTokenResponse.accessToken}")

        val kakaoId = userinfo.id.toString()
        return kakaoId
    }

    fun setKakaoIdToMember(code: String, redirectUrl: String, loginMember: LoginMember) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val kakaoId = getKakaoId(redirectUrl, code)
        member.kakaoId = kakaoId
    }

    fun loginForSpa(
        req: HttpServletRequest,
        code: String,
        redirectUrl: String,
        spaCallbackUrl: String
    ): ResponseEntity<Void> {
        val kakaoId = getKakaoId(redirectUrl, code)

        val member = memberRepository.findMemberByKakaoId(kakaoId)
        if (member != null) {
            log.info("Kakao Login Success (SPA): ${member.name}, $kakaoId")
            val tokenResponse = authService.getTokenResponseByMemberId(member.id!!, req)

            val fragmentParams = buildFragmentParams(tokenResponse)
            return ResponseEntity
                .status(HttpStatus.FOUND)
                .location(URI.create("$spaCallbackUrl#$fragmentParams"))
                .build()
        }

        val ssoRegister = MemberSsoRegisterRepository.save(MemberSsoRegister(ssoId = kakaoId, ssoType = SsoType.KAKAO))
        val errorFragment = "error=sso_required&uuid=${ssoRegister.uuid}"

        return ResponseEntity
            .status(HttpStatus.FOUND)
            .location(URI.create("$spaCallbackUrl#$errorFragment"))
            .build()
    }

    private fun buildFragmentParams(tokenResponse: TokenResponse): String {
        return listOf(
            "access_token" to tokenResponse.accessToken,
            "refresh_token" to tokenResponse.refreshToken,
            "expires_in" to tokenResponse.expiresIn.toString(),
            "token_type" to tokenResponse.tokenType
        ).joinToString("&") { (key, value) ->
            "$key=${URLEncoder.encode(value, StandardCharsets.UTF_8)}"
        }
    }

}
