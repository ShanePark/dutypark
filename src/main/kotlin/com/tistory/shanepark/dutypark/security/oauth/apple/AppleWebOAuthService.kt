package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResult
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthPurpose
import jakarta.servlet.http.HttpServletRequest
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
class AppleWebOAuthService(
    private val exchangeService: AppleNativeOAuthService,
    @param:Value("\${oauth.apple.web-client-id:}") private val webClientId: String,
    @param:Value("\${oauth.apple.web-redirect-uri:}") private val webRedirectUri: String,
) {
    @Transactional
    fun exchange(
        request: AppleWebExchangeRequest,
        loginMember: LoginMember?,
        servletRequest: HttpServletRequest,
    ): MobileOAuthExchangeResult {
        if (request.purpose !in setOf(MobileOAuthPurpose.LOGIN, MobileOAuthPurpose.LINK)) {
            throw IllegalArgumentException("auth.apple.purpose.invalid")
        }
        if (webClientId.isBlank() || webRedirectUri.isBlank()) {
            throw AppleOAuthException("auth.apple.configurationUnavailable", 503)
        }
        return exchangeService.exchangeForClient(
            AppleNativeExchangeRequest(
                identityToken = request.identityToken,
                authorizationCode = request.authorizationCode,
                nonce = request.rawNonce,
                purpose = request.purpose,
            ),
            loginMember,
            servletRequest,
            webClientId,
            webRedirectUri,
        )
    }
}
