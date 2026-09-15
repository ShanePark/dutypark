package com.tistory.shanepark.dutypark.security.oauth.mobile

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoAccessTokenInfoApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoTokenApi
import com.tistory.shanepark.dutypark.security.oauth.kakao.KakaoUserInfoApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverRefreshTokenApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverTokenApi
import com.tistory.shanepark.dutypark.security.oauth.naver.NaverUserInfoApi
import org.springframework.beans.factory.annotation.Value
import org.springframework.web.client.RestClientResponseException
import org.springframework.stereotype.Service

@Service
class MobileOAuthProviderGateway(
    private val kakaoTokenApi: KakaoTokenApi,
    private val kakaoUserInfoApi: KakaoUserInfoApi,
    private val kakaoAccessTokenInfoApi: KakaoAccessTokenInfoApi,
    private val naverTokenApi: NaverTokenApi,
    private val naverRefreshTokenApi: NaverRefreshTokenApi,
    private val naverUserInfoApi: NaverUserInfoApi,
    @param:Value("\${oauth.kakao.rest-api-key}") private val kakaoRestApiKey: String,
    @param:Value("\${oauth.kakao.app-id:}") private val kakaoAppId: String,
    @param:Value("\${oauth.naver.client-id}") private val naverClientId: String,
    @param:Value("\${oauth.naver.client-secret}") private val naverClientSecret: String,
) {
    private val log = logger()

    fun getSocialId(provider: SsoType, code: String, state: String, redirectUri: String): String {
        return when (provider) {
            SsoType.KAKAO -> getKakaoId(code, redirectUri)
            SsoType.NAVER -> getNaverId(code, state)
            SsoType.APPLE -> throw IllegalArgumentException("auth.oauth.mobile.provider.invalid")
        }
    }

    fun nativeCapabilities(): List<String> = buildList {
        if (kakaoAppIdAsLong() != null) {
            add(SsoType.KAKAO.name)
        }
        if (naverConfigured()) {
            add(SsoType.NAVER.name)
        }
    }

    fun validateNativeCredentialShape(
        provider: SsoType,
        accessToken: String?,
        refreshToken: String?,
    ) {
        when (provider) {
            SsoType.KAKAO -> {
                requiredToken(accessToken, "auth.oauth.mobile.native.accessToken.required")
                if (!refreshToken.isNullOrBlank()) {
                    throw IllegalArgumentException("auth.oauth.mobile.native.refreshToken.unexpected")
                }
            }

            SsoType.NAVER -> {
                if (!accessToken.isNullOrBlank()) {
                    throw IllegalArgumentException("auth.oauth.mobile.native.accessToken.unexpected")
                }
                requiredToken(refreshToken, "auth.oauth.mobile.native.refreshToken.required")
            }

            SsoType.APPLE -> throw IllegalArgumentException("auth.oauth.mobile.provider.invalid")
        }
    }

    fun getNativeSocialId(
        provider: SsoType,
        accessToken: String?,
        refreshToken: String?,
    ): String {
        return when (provider) {
            SsoType.KAKAO -> getNativeKakaoId(accessToken, refreshToken)
            SsoType.NAVER -> getNativeNaverId(accessToken, refreshToken)
            SsoType.APPLE -> throw IllegalArgumentException("auth.oauth.mobile.provider.invalid")
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

    private fun getNativeKakaoId(accessToken: String?, refreshToken: String?): String {
        ensureKakaoConfigured()
        val token = requiredToken(accessToken, "auth.oauth.mobile.native.accessToken.required")
        if (!refreshToken.isNullOrBlank()) {
            throw IllegalArgumentException("auth.oauth.mobile.native.refreshToken.unexpected")
        }

        val tokenInfo = providerCall(SsoType.KAKAO) {
            kakaoAccessTokenInfoApi.getAccessTokenInfo("Bearer $token")
        }
        val configuredAppId = requireNotNull(kakaoAppIdAsLong())
        if (
            tokenInfo.appId != configuredAppId ||
            tokenInfo.id == null ||
            tokenInfo.id <= 0L ||
            tokenInfo.expiresIn == null ||
            tokenInfo.expiresIn <= 0L
        ) {
            throw MobileOAuthNativeException("auth.oauth.mobile.provider.failed")
        }
        return tokenInfo.id.toString()
    }

    private fun getNativeNaverId(accessToken: String?, refreshToken: String?): String {
        ensureNaverConfigured()
        if (!accessToken.isNullOrBlank()) {
            throw IllegalArgumentException("auth.oauth.mobile.native.accessToken.unexpected")
        }
        val providerRefreshToken = requiredToken(
            refreshToken,
            "auth.oauth.mobile.native.refreshToken.required",
        )
        val tokenResponse = providerCall(SsoType.NAVER) {
            naverRefreshTokenApi.refreshAccessToken(
                grantType = "refresh_token",
                clientId = naverClientId,
                clientSecret = naverClientSecret,
                refreshToken = providerRefreshToken,
            )
        }
        val token = tokenResponse.accessToken
            ?.takeIf(String::isNotBlank)
            ?: throw MobileOAuthNativeException("auth.oauth.mobile.provider.failed")
        val userInfo = providerCall(SsoType.NAVER) {
            naverUserInfoApi.getUserInfo("Bearer $token")
        }
        if (userInfo.resultCode != "00" || userInfo.response.id.isBlank()) {
            throw MobileOAuthNativeException("auth.oauth.mobile.provider.failed")
        }
        return userInfo.response.id
    }

    private fun ensureKakaoConfigured() {
        if (kakaoAppIdAsLong() == null) {
            throw MobileOAuthNativeException("auth.oauth.mobile.provider.unavailable", 503)
        }
    }

    private fun ensureNaverConfigured() {
        if (!naverConfigured()) {
            throw MobileOAuthNativeException("auth.oauth.mobile.provider.unavailable", 503)
        }
    }

    private fun kakaoAppIdAsLong(): Long? = kakaoAppId.trim().toLongOrNull()?.takeIf { it > 0L }

    private fun naverConfigured(): Boolean =
        naverClientId.isNotBlank() && naverClientSecret.isNotBlank()

    private fun requiredToken(token: String?, message: String): String =
        token?.takeIf(String::isNotBlank) ?: throw IllegalArgumentException(message)

    private fun <T> providerCall(provider: SsoType, call: () -> T): T {
        return try {
            call()
        } catch (e: MobileOAuthNativeException) {
            throw e
        } catch (e: Exception) {
            log.warn(
                "Native OAuth provider call failed. provider={}, error={}",
                provider,
                e.javaClass.simpleName,
            )
            throw MobileOAuthNativeException(
                message = "auth.oauth.mobile.provider.failed",
                errorCode = providerErrorCode(e),
                cause = e,
            )
        }
    }

    private fun providerErrorCode(exception: Exception): Int {
        val status = (exception as? RestClientResponseException)?.statusCode?.value()
            ?: return 503
        return when {
            status == 429 -> 503
            status in 400..499 -> 400
            else -> 503
        }
    }
}
