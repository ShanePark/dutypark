package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverTokenApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoApi
import org.springframework.beans.factory.annotation.Value
import org.springframework.stereotype.Service

@Service
class MobileOAuthProviderGateway(
    private val kakaoTokenApi: KakaoTokenApi,
    private val kakaoUserInfoApi: KakaoUserInfoApi,
    private val naverTokenApi: NaverTokenApi,
    private val naverUserInfoApi: NaverUserInfoApi,
    @param:Value("\${oauth.kakao.rest-api-key}") private val kakaoRestApiKey: String,
    @param:Value("\${oauth.naver.client-id}") private val naverClientId: String,
    @param:Value("\${oauth.naver.client-secret}") private val naverClientSecret: String,
) {
    private val log = logger()

    fun getSocialId(provider: SsoType, code: String, state: String, redirectUri: String): String {
        return when (provider) {
            SsoType.KAKAO -> getKakaoId(code, redirectUri)
            SsoType.NAVER -> getNaverId(code, state)
        }
    }

    private fun getKakaoId(code: String, redirectUri: String): String {
        val token = kakaoTokenApi.getAccessToken(
            grantType = "authorization_code",
            clientId = kakaoRestApiKey,
            redirectUri = redirectUri,
            code = code,
        )
        return kakaoUserInfoApi.getUserInfo("Bearer ${token.accessToken}").id.toString()
    }

    private fun getNaverId(code: String, state: String): String {
        val token = naverTokenApi.getAccessToken(
            grantType = "authorization_code",
            clientId = naverClientId,
            clientSecret = naverClientSecret,
            code = code,
            state = state,
        )
        val accessToken = token.accessToken ?: run {
            log.warn("Failed to exchange Naver mobile OAuth token. error={}", token.error)
            throw IllegalArgumentException("auth.oauth.mobile.provider.failed")
        }
        val userInfo = naverUserInfoApi.getUserInfo("Bearer $accessToken")
        if (userInfo.resultCode != "00") {
            throw IllegalArgumentException("auth.oauth.mobile.provider.failed")
        }
        return userInfo.response.id
    }
}
