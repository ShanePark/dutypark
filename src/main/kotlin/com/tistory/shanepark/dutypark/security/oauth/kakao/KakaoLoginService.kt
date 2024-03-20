package com.tistory.shanepark.dutypark.security.oauth.kakao

import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.slf4j.Logger
import org.slf4j.LoggerFactory
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Service
import java.net.URI

@Service
class KakaoLoginService(
    private val kakaoTokenApi: KakaoTokenApi,
    private val kakaoUserInfoApi: KakaoUserInfoApi,
    private val memberRepository: MemberRepository,
    private val authService: AuthService,
    private val MemberSsoRegisterRepository: MemberSsoRegisterRepository,
    @Value("\${oauth.kakao.rest-api-key}") private val restApiKey: String
) {
    val log: Logger = LoggerFactory.getLogger(KakaoLoginService::class.java)

    fun login(req: HttpServletRequest, code: String, redirectUrl: String, referer: String): ResponseEntity<Any> {
        val kakaoTokenResponse = kakaoTokenApi.getAccessToken(
            grantType = "authorization_code",
            clientId = restApiKey,
            redirectUri = redirectUrl,
            code = code
        )

        val userinfo = kakaoUserInfoApi.getUserInfo(accessToken = "Bearer ${kakaoTokenResponse.accessToken}")

        val kakaoId = userinfo.id.toString()
        log.info("Kakao Login Success: $kakaoId")

        val member = memberRepository.findMemberByKakaoId(kakaoId)
        if (member != null) {
            val headers = authService.getLoginCookieHeaders(
                memberId = member.id,
                req = req,
                rememberMe = false,
                rememberMeEmail = null,
            )
            return ResponseEntity
                .status(HttpStatus.FOUND)
                .headers(headers)
                .location(getLocation(referer)).build()
        }

        val ssoRegister = MemberSsoRegisterRepository.save(MemberSsoRegister(ssoId = kakaoId, ssoType = SsoType.KAKAO))

        return ResponseEntity.status(HttpStatus.FOUND)
            .location(URI.create("/sso-signup?uuid=${ssoRegister.uuid}"))
            .build()
    }

    private fun getLocation(referer: String): URI {
        var refererValue = referer.ifEmpty { "/" }
        if (refererValue.contains("/login")) {
            refererValue = "/"
        }
        return URI.create(refererValue)
    }

}
