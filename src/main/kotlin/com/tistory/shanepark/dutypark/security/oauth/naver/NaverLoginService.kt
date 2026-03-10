package com.tistory.shanepark.dutypark.security.oauth.naver

import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.buildOAuthCallbackUri
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import jakarta.servlet.http.HttpServletRequest
import jakarta.servlet.http.HttpServletResponse
import org.springframework.beans.factory.annotation.Value
import org.springframework.http.HttpStatus
import org.springframework.http.ResponseEntity
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class NaverLoginService(
    private val naverTokenApi: NaverTokenApi,
    private val naverUserInfoApi: NaverUserInfoApi,
    private val memberRepository: MemberRepository,
    private val authService: AuthService,
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository,
    private val memberSocialAccountService: MemberSocialAccountService,
    private val cookieService: CookieService,
    @param:Value("\${oauth.naver.client-id}") private val clientId: String,
    @param:Value("\${oauth.naver.client-secret}") private val clientSecret: String,
) {

    private fun getNaverId(code: String, state: String): String {
        val tokenResponse = naverTokenApi.getAccessToken(
            grantType = "authorization_code",
            clientId = clientId,
            clientSecret = clientSecret,
            code = code,
            state = state
        )

        val userInfo = naverUserInfoApi.getUserInfo(accessToken = "Bearer ${tokenResponse.accessToken}")
        check(userInfo.resultCode == "00") { "Failed to fetch Naver user info: ${userInfo.message}" }
        return userInfo.response.id
    }

    fun setNaverIdToMember(code: String, state: String, loginMember: LoginMember) {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        val naverId = getNaverId(code = code, state = state)
        memberSocialAccountService.link(member, SsoType.NAVER, naverId)
    }

    fun login(
        req: HttpServletRequest,
        resp: HttpServletResponse,
        code: String,
        state: String,
        callbackUrl: String,
        redirectTarget: String? = null
    ): ResponseEntity<Void> {
        val naverId = getNaverId(code = code, state = state)

        val member = memberSocialAccountService.findMemberByProviderAndSocialId(SsoType.NAVER, naverId)
        if (member != null) {
            val tokenResponse = authService.getTokenResponseByMemberId(member.id!!, req)
            cookieService.setTokenCookies(resp, tokenResponse.accessToken, tokenResponse.refreshToken)

            return ResponseEntity.status(HttpStatus.FOUND)
                .location(
                    buildOAuthCallbackUri(
                        callbackUrl = callbackUrl,
                        redirectTarget = redirectTarget,
                        "login" to "success"
                    )
                )
                .build()
        }

        val ssoRegister = memberSsoRegisterRepository.save(MemberSsoRegister(ssoId = naverId, ssoType = SsoType.NAVER))

        return ResponseEntity.status(HttpStatus.FOUND)
            .location(
                buildOAuthCallbackUri(
                    callbackUrl = callbackUrl,
                    redirectTarget = redirectTarget,
                    "error" to "sso_required",
                    "uuid" to ssoRegister.uuid
                )
            )
            .build()
    }
}
