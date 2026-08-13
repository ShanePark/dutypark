package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthPurpose
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import com.tistory.shanepark.dutypark.security.service.AuthService
import jakarta.servlet.http.HttpServletRequest
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.mockito.kotlin.*
import java.util.Optional

class AppleNativeOAuthServiceTest {
    private val verifier: AppleIdentityTokenVerifier = mock()
    private val provider: AppleProviderClient = mock()
    private val secrets: AppleClientSecretFactory = mock()
    private val replay: AppleIdentityTokenReplayService = mock()
    private val credentials: AppleCredentialService = mock()
    private val social: MemberSocialAccountService = mock()
    private val members: MemberRepository = mock()
    private val signups: MemberSsoRegisterRepository = mock()
    private val auth: AuthService = mock()
    private val reauth: ReauthService = mock()
    private val servletRequest: HttpServletRequest = mock()
    private lateinit var service: AppleNativeOAuthService

    @BeforeEach
    fun setUp() {
        service = AppleNativeOAuthService(
            verifier, provider, secrets, replay, credentials, social, members, signups, auth, reauth
        )
        whenever(secrets.clientId()).thenReturn("io.github.shanepark.dutypark")
        whenever(secrets.create()).thenReturn("client-secret")
        whenever(verifier.verify(eq(IDENTITY_TOKEN), eq(RAW_NONCE), eq(true)))
            .thenReturn(VerifiedAppleIdentity(SUBJECT, 1_800_000_000))
        whenever(provider.exchange(AUTHORIZATION_CODE, "io.github.shanepark.dutypark", "client-secret"))
            .thenReturn(AppleTokenResponse(refresh_token = "refresh-token", id_token = EXCHANGE_ID_TOKEN))
        whenever(verifier.verify(eq(EXCHANGE_ID_TOKEN), isNull(), eq(false)))
            .thenReturn(VerifiedAppleIdentity(SUBJECT, 1_800_000_000))
    }

    @Test
    fun `existing Apple mapping logs in and returns normal session tokens`() {
        val member: Member = mock { on { id } doReturn 7L }
        whenever(social.findMemberByProviderAndSocialId(any(), eq(SUBJECT))).thenReturn(member)
        whenever(auth.getTokenResponseByMemberId(7L, servletRequest))
            .thenReturn(TokenResponse("access", "refresh", 1800))

        val result = service.exchange(request(), null, servletRequest)

        assertThat(result.response.signupRequired).isFalse()
        assertThat(result.accessToken).isEqualTo("access")
        verify(credentials).upsert(SUBJECT, "refresh-token")
        verify(replay).consume(any(), eq(1_800_000_000))
    }

    @Test
    fun `new Apple subject returns signup uuid without email based merging`() {
        whenever(social.findMemberByProviderAndSocialId(any(), eq(SUBJECT))).thenReturn(null)
        whenever(signups.save(any())).thenAnswer { it.arguments[0] as MemberSsoRegister }

        val result = service.exchange(request(), null, servletRequest)

        assertThat(result.response.signupRequired).isTrue()
        assertThat(result.response.signupUuid).isNotBlank()
        verifyNoInteractions(auth)
    }

    @Test
    fun `link requires authentication and links verified subject`() {
        val member: Member = mock()
        whenever(members.findById(7L)).thenReturn(Optional.of(member))

        service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)

        verify(social).link(member, com.tistory.shanepark.dutypark.member.domain.enums.SsoType.APPLE, SUBJECT)
        verify(credentials).upsert(SUBJECT, "refresh-token")
    }

    @Test
    fun `delete account rejects a different Apple subject`() {
        whenever(social.findMemberByProviderAndSocialId(any(), eq(SUBJECT))).thenReturn(null)

        val exception = assertThrows<AppleOAuthException> {
            service.exchange(request(MobileOAuthPurpose.DELETE_ACCOUNT), loginMember(), servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.apple.accountMismatch")
        verifyNoInteractions(reauth)
    }

    @Test
    fun `configuration is checked before token verification or provider network`() {
        whenever(secrets.clientId()).thenThrow(AppleOAuthException("auth.apple.configurationUnavailable", 503))

        val exception = assertThrows<AppleOAuthException> { service.exchange(request(), null, servletRequest) }

        assertThat(exception.message).isEqualTo("auth.apple.configurationUnavailable")
        verifyNoInteractions(provider)
        verify(verifier, never()).verify(any(), any(), any())
    }

    @Test
    fun `token exchange response missing refresh token is invalid`() {
        whenever(provider.exchange(AUTHORIZATION_CODE, "io.github.shanepark.dutypark", "client-secret"))
            .thenReturn(AppleTokenResponse(id_token = EXCHANGE_ID_TOKEN))

        val exception = assertThrows<AppleOAuthException> {
            service.exchange(request(), null, servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.apple.credential.invalid")
        verify(credentials, never()).upsert(any(), any())
    }

    private fun request(purpose: MobileOAuthPurpose = MobileOAuthPurpose.LOGIN) = AppleNativeExchangeRequest(
        identityToken = IDENTITY_TOKEN,
        authorizationCode = AUTHORIZATION_CODE,
        nonce = RAW_NONCE,
        purpose = purpose,
    )

    private fun loginMember() = LoginMember(7L, name = "member")

    companion object {
        private const val IDENTITY_TOKEN = "identity-token"
        private const val EXCHANGE_ID_TOKEN = "exchange-id-token"
        private const val AUTHORIZATION_CODE = "authorization-code"
        private const val RAW_NONCE = "raw-nonce-value-that-is-long-enough"
        private const val SUBJECT = "apple-subject"
    }
}
