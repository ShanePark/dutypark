package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthExchangeResult
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthPurpose
import jakarta.servlet.http.HttpServletRequest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.params.ParameterizedTest
import org.junit.jupiter.params.provider.EnumSource
import org.mockito.kotlin.anyOrNull
import org.mockito.kotlin.any
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever

class AppleWebOAuthServiceTest {
    private val exchangeService: AppleNativeOAuthService = mock()
    private val servletRequest: HttpServletRequest = mock()

    @Test
    fun `uses only configured web client id and redirect uri`() {
        val service = AppleWebOAuthService(exchangeService, WEB_CLIENT_ID, WEB_REDIRECT_URI)
        val expected = MobileOAuthExchangeResult(MobileOAuthExchangeResponse(signupRequired = true))
        whenever(
            exchangeService.exchangeForClient(
                AppleNativeExchangeRequest(IDENTITY_TOKEN, AUTHORIZATION_CODE, RAW_NONCE),
                null,
                servletRequest,
                WEB_CLIENT_ID,
                WEB_REDIRECT_URI,
            )
        ).thenReturn(expected)

        val result = service.exchange(
            AppleWebExchangeRequest(IDENTITY_TOKEN, AUTHORIZATION_CODE, RAW_NONCE),
            null,
            servletRequest,
        )

        assertThat(result).isSameAs(expected)
        verify(exchangeService).exchangeForClient(
            AppleNativeExchangeRequest(IDENTITY_TOKEN, AUTHORIZATION_CODE, RAW_NONCE),
            null,
            servletRequest,
            WEB_CLIENT_ID,
            WEB_REDIRECT_URI,
        )
    }

    @Test
    fun `link delegates authenticated member with configured web client`() {
        val service = AppleWebOAuthService(exchangeService, WEB_CLIENT_ID, WEB_REDIRECT_URI)
        val loginMember = LoginMember(7L, name = "member")
        val request = AppleWebExchangeRequest(
            IDENTITY_TOKEN,
            AUTHORIZATION_CODE,
            RAW_NONCE,
            MobileOAuthPurpose.LINK,
        )
        val expected = MobileOAuthExchangeResult(MobileOAuthExchangeResponse(signupRequired = false))
        whenever(
            exchangeService.exchangeForClient(
                any(),
                eq(loginMember),
                eq(servletRequest),
                eq(WEB_CLIENT_ID),
                eq(WEB_REDIRECT_URI),
            )
        ).thenReturn(expected)

        val result = service.exchange(request, loginMember, servletRequest)

        assertThat(result).isSameAs(expected)
        verify(exchangeService).exchangeForClient(
            AppleNativeExchangeRequest(
                IDENTITY_TOKEN,
                AUTHORIZATION_CODE,
                RAW_NONCE,
                MobileOAuthPurpose.LINK,
            ),
            loginMember,
            servletRequest,
            WEB_CLIENT_ID,
            WEB_REDIRECT_URI,
        )
    }

    @Test
    fun `blank web configuration fails before exchange`() {
        val service = AppleWebOAuthService(exchangeService, "", "")

        val exception = assertThrows<AppleOAuthException> {
            service.exchange(
                AppleWebExchangeRequest(IDENTITY_TOKEN, AUTHORIZATION_CODE, RAW_NONCE),
                null,
                servletRequest,
            )
        }

        assertThat(exception.message).isEqualTo("auth.apple.configurationUnavailable")
        verify(exchangeService, org.mockito.kotlin.never()).exchangeForClient(
            org.mockito.kotlin.any(),
            anyOrNull(),
            org.mockito.kotlin.any(),
            org.mockito.kotlin.any(),
            org.mockito.kotlin.any(),
        )
    }

    @ParameterizedTest
    @EnumSource(
        value = MobileOAuthPurpose::class,
        names = ["DELETE_ACCOUNT"],
    )
    fun `rejects delete account purpose`(purpose: MobileOAuthPurpose) {
        val service = AppleWebOAuthService(exchangeService, WEB_CLIENT_ID, WEB_REDIRECT_URI)

        val exception = assertThrows<IllegalArgumentException> {
            service.exchange(
                AppleWebExchangeRequest(IDENTITY_TOKEN, AUTHORIZATION_CODE, RAW_NONCE, purpose),
                null,
                servletRequest,
            )
        }

        assertThat(exception.message).isEqualTo("auth.apple.purpose.invalid")
        verify(exchangeService, org.mockito.kotlin.never()).exchangeForClient(
            org.mockito.kotlin.any(),
            anyOrNull(),
            org.mockito.kotlin.any(),
            org.mockito.kotlin.any(),
            org.mockito.kotlin.any(),
        )
    }

    companion object {
        private const val IDENTITY_TOKEN = "identity-token"
        private const val AUTHORIZATION_CODE = "authorization-code"
        private const val RAW_NONCE = "raw-nonce-value-that-is-long-enough"
        private const val WEB_CLIENT_ID = "io.github.shanepark.dutypark.web"
        private const val WEB_REDIRECT_URI = "https://dutypark.com/auth/apple/callback"
    }
}
