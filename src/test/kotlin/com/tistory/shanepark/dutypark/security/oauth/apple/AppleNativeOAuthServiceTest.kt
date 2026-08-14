package com.tistory.shanepark.dutypark.security.oauth.apple

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.oauth.mobile.MobileOAuthPurpose
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
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
        whenever(secrets.create("io.github.shanepark.dutypark")).thenReturn("client-secret")
        whenever(verifier.verify(eq(IDENTITY_TOKEN), eq(RAW_NONCE), eq("io.github.shanepark.dutypark"), eq(true)))
            .thenReturn(VerifiedAppleIdentity(SUBJECT, 1_800_000_000))
        whenever(provider.exchange(AUTHORIZATION_CODE, "io.github.shanepark.dutypark", "client-secret"))
            .thenReturn(AppleTokenResponse(refresh_token = "refresh-token", id_token = EXCHANGE_ID_TOKEN))
        whenever(verifier.verify(eq(EXCHANGE_ID_TOKEN), isNull(), eq("io.github.shanepark.dutypark"), eq(false)))
            .thenReturn(VerifiedAppleIdentity(SUBJECT, 1_800_000_000))
    }

    @Test
    fun `existing Apple mapping logs in and returns normal session tokens`() {
        val member: Member = mock {
            on { id } doReturn 7L
            on { status } doReturn MemberStatus.ACTIVE
        }
        whenever(social.findMemberByProviderAndSocialId(any(), eq(SUBJECT))).thenReturn(member)
        whenever(members.findMemberWithTeamForUpdate(7L)).thenReturn(Optional.of(member))
        whenever(auth.getTokenResponseByMemberId(7L, servletRequest))
            .thenReturn(TokenResponse("access", "refresh", 1800))

        val result = service.exchange(request(), null, servletRequest)

        assertThat(result.response.signupRequired).isFalse()
        assertThat(result.accessToken).isEqualTo("access")
        verify(credentials).upsert(SUBJECT, "refresh-token", "io.github.shanepark.dutypark")
        verify(replay).consume(any(), eq(1_800_000_000))
        val order = inOrder(members, provider)
        order.verify(members).findMemberWithTeamForUpdate(7L)
        order.verify(provider).exchange(
            AUTHORIZATION_CODE,
            "io.github.shanepark.dutypark",
            "client-secret",
            null,
        )
    }

    @Test
    fun `deletion pending Apple member is rejected before provider code exchange`() {
        val member: Member = mock {
            on { id } doReturn 7L
            on { status } doReturn MemberStatus.DELETION_PENDING
        }
        whenever(social.findMemberByProviderAndSocialId(any(), eq(SUBJECT))).thenReturn(member)
        whenever(members.findMemberWithTeamForUpdate(7L)).thenReturn(Optional.of(member))

        val exception = assertThrows<AuthException> {
            service.exchange(request(), null, servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.account.inactive")
        verify(members).findMemberWithTeamForUpdate(7L)
        verify(provider, never()).exchange(any(), any(), any(), anyOrNull())
        verify(credentials, never()).upsert(any(), any(), any())
        verify(replay, never()).consume(any(), any())
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
        val member = activeMember()
        stubActiveLinkMember(member)

        service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)

        verify(social).link(member, SsoType.APPLE, SUBJECT)
        verify(credentials).upsert(SUBJECT, "refresh-token", "io.github.shanepark.dutypark")
        verify(provider, never()).revoke(any(), any(), any())
        val order = inOrder(members, provider)
        order.verify(members).findMemberWithTeamForUpdate(7L)
        order.verify(provider).exchange(
            AUTHORIZATION_CODE,
            "io.github.shanepark.dutypark",
            "client-secret",
            null,
        )
    }

    @Test
    fun `link conflict revokes newly issued credential with selected web client and preserves conflict`() {
        stubWebExchange()
        val member = activeMember()
        val conflict = SocialAccountAlreadyLinkedException(SsoType.APPLE)
        stubActiveLinkMember(member)
        whenever(social.link(member, SsoType.APPLE, SUBJECT)).thenThrow(conflict)

        val thrown = assertThrows<SocialAccountAlreadyLinkedException> {
            service.exchangeForClient(
                request(MobileOAuthPurpose.LINK),
                loginMember(),
                servletRequest,
                WEB_CLIENT_ID,
                WEB_REDIRECT_URI,
            )
        }

        assertThat(thrown).isSameAs(conflict)
        verify(provider).revoke("web-refresh-token", WEB_CLIENT_ID, "web-client-secret")
        verify(credentials, never()).upsert(any(), any(), any())
    }

    @Test
    fun `link credential persistence failure revokes newly issued credential and preserves failure`() {
        val member = activeMember()
        val persistenceFailure = IllegalStateException("credential persistence failed")
        stubActiveLinkMember(member)
        whenever(credentials.upsert(SUBJECT, "refresh-token", "io.github.shanepark.dutypark"))
            .thenThrow(persistenceFailure)

        val thrown = assertThrows<IllegalStateException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(thrown).isSameAs(persistenceFailure)
        verify(social).link(member, SsoType.APPLE, SUBJECT)
        verify(provider).revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret")
    }

    @Test
    fun `link compensation failure keeps original failure and records revoke failure`() {
        val member = activeMember()
        val conflict = SocialAccountAlreadyLinkedException(SsoType.APPLE)
        val revokeFailure = AppleOAuthException("auth.apple.provider.unavailable", 503)
        stubActiveLinkMember(member)
        whenever(social.link(member, SsoType.APPLE, SUBJECT)).thenThrow(conflict)
        whenever(provider.revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret"))
            .thenThrow(revokeFailure)

        val thrown = assertThrows<SocialAccountAlreadyLinkedException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(thrown).isSameAs(conflict)
        assertThat(thrown.suppressed).containsExactly(revokeFailure)
        verify(credentials).storeRevocationRetry("refresh-token", "io.github.shanepark.dutypark")
    }

    @Test
    fun `link retry persistence failure preserves original and both compensation failures`() {
        val member = activeMember()
        val conflict = SocialAccountAlreadyLinkedException(SsoType.APPLE)
        val revokeFailure = AppleOAuthException("auth.apple.provider.unavailable", 503)
        val retryPersistenceFailure = IllegalStateException("retry persistence failed")
        stubActiveLinkMember(member)
        whenever(social.link(member, SsoType.APPLE, SUBJECT)).thenThrow(conflict)
        whenever(provider.revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret"))
            .thenThrow(revokeFailure)
        whenever(credentials.storeRevocationRetry("refresh-token", "io.github.shanepark.dutypark"))
            .thenThrow(retryPersistenceFailure)

        val thrown = assertThrows<SocialAccountAlreadyLinkedException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(thrown).isSameAs(conflict)
        assertThat(thrown.suppressed).containsExactly(revokeFailure, retryPersistenceFailure)
    }

    @Test
    fun `link missing exchanged identity token revokes newly issued credential`() {
        val member = activeMember()
        stubActiveLinkMember(member)
        whenever(provider.exchange(AUTHORIZATION_CODE, "io.github.shanepark.dutypark", "client-secret"))
            .thenReturn(AppleTokenResponse(refresh_token = "refresh-token"))

        val exception = assertThrows<AppleOAuthException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.apple.credential.invalid")
        verify(provider).revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret")
        verifyNoInteractions(social)
    }

    @Test
    fun `link exchanged identity verification failure revokes newly issued credential`() {
        val member = activeMember()
        stubActiveLinkMember(member)
        val verificationFailure = AppleOAuthException("auth.apple.credential.invalid")
        whenever(verifier.verify(EXCHANGE_ID_TOKEN, null, "io.github.shanepark.dutypark", false))
            .thenThrow(verificationFailure)

        val thrown = assertThrows<AppleOAuthException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(thrown).isSameAs(verificationFailure)
        verify(provider).revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret")
        verifyNoInteractions(social)
    }

    @Test
    fun `link exchanged subject mismatch revokes newly issued credential`() {
        val member = activeMember()
        stubActiveLinkMember(member)
        whenever(verifier.verify(EXCHANGE_ID_TOKEN, null, "io.github.shanepark.dutypark", false))
            .thenReturn(VerifiedAppleIdentity("different-subject", 1_800_000_000))

        val exception = assertThrows<AppleOAuthException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.apple.credential.invalid")
        verify(provider).revoke("refresh-token", "io.github.shanepark.dutypark", "client-secret")
        verifyNoInteractions(social)
    }

    @Test
    fun `inactive link member is rejected before identity replay or provider exchange`() {
        val member: Member = mock {
            on { id } doReturn 7L
            on { status } doReturn MemberStatus.DELETION_PENDING
        }
        whenever(members.findMemberWithTeamForUpdate(7L)).thenReturn(Optional.of(member))

        val exception = assertThrows<AuthException> {
            service.exchange(request(MobileOAuthPurpose.LINK), loginMember(), servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.account.inactive")
        verify(verifier, never()).verify(any(), any(), any(), any())
        verifyNoInteractions(provider, replay)
    }

    @Test
    fun `link without authentication is rejected before consuming provider credentials`() {
        assertThrows<AuthException> {
            service.exchange(request(MobileOAuthPurpose.LINK), null, servletRequest)
        }

        verifyNoInteractions(provider, replay)
        verify(verifier, never()).verify(any(), any(), any(), any())
    }

    @Test
    fun `link while impersonating is rejected before consuming provider credentials`() {
        val impersonating = loginMember().copy(isImpersonating = true, originalMemberId = 9L)

        val exception = assertThrows<AuthException> {
            service.exchange(request(MobileOAuthPurpose.LINK), impersonating, servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.reauth.impersonationForbidden")
        verifyNoInteractions(provider, replay)
        verify(verifier, never()).verify(any(), any(), any(), any())
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
        verify(verifier, never()).verify(any(), any(), any(), any())
    }

    @Test
    fun `token exchange response missing refresh token is invalid`() {
        whenever(provider.exchange(AUTHORIZATION_CODE, "io.github.shanepark.dutypark", "client-secret"))
            .thenReturn(AppleTokenResponse(id_token = EXCHANGE_ID_TOKEN))

        val exception = assertThrows<AppleOAuthException> {
            service.exchange(request(), null, servletRequest)
        }

        assertThat(exception.message).isEqualTo("auth.apple.credential.invalid")
        verify(credentials, never()).upsert(any(), any(), any())
    }

    @Test
    fun `web exchange uses selected services id and redirect uri`() {
        stubWebExchange()
        whenever(social.findMemberByProviderAndSocialId(any(), eq(SUBJECT))).thenReturn(null)
        whenever(signups.save(any())).thenAnswer { it.arguments[0] as MemberSsoRegister }

        service.exchangeForClient(request(), null, servletRequest, WEB_CLIENT_ID, WEB_REDIRECT_URI)

        verify(credentials).upsert(SUBJECT, "web-refresh-token", WEB_CLIENT_ID)
    }

    private fun stubWebExchange() {
        whenever(secrets.create(WEB_CLIENT_ID)).thenReturn("web-client-secret")
        whenever(verifier.verify(IDENTITY_TOKEN, RAW_NONCE, WEB_CLIENT_ID, true))
            .thenReturn(VerifiedAppleIdentity(SUBJECT, 1_800_000_000))
        whenever(provider.exchange(AUTHORIZATION_CODE, WEB_CLIENT_ID, "web-client-secret", WEB_REDIRECT_URI))
            .thenReturn(AppleTokenResponse(refresh_token = "web-refresh-token", id_token = EXCHANGE_ID_TOKEN))
        whenever(verifier.verify(EXCHANGE_ID_TOKEN, null, WEB_CLIENT_ID, false))
            .thenReturn(VerifiedAppleIdentity(SUBJECT, 1_800_000_000))
    }

    private fun activeMember(): Member = mock {
        on { id } doReturn 7L
        on { status } doReturn MemberStatus.ACTIVE
    }

    private fun stubActiveLinkMember(member: Member) {
        whenever(members.findMemberWithTeamForUpdate(7L)).thenReturn(Optional.of(member))
        whenever(members.findById(7L)).thenReturn(Optional.of(member))
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
        private const val WEB_CLIENT_ID = "io.github.shanepark.dutypark.web"
        private const val WEB_REDIRECT_URI = "https://dutypark.com/auth/apple/callback"
    }
}
