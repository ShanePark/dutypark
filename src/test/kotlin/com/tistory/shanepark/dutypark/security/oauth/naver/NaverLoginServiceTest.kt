package com.tistory.shanepark.dutypark.security.oauth.naver

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.eq
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.http.HttpStatus
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class NaverLoginServiceTest {

    private val naverTokenApi: NaverTokenApi = mock()
    private val naverUserInfoApi: NaverUserInfoApi = mock()
    private val memberRepository: MemberRepository = mock()
    private val authService: AuthService = mock()
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository = mock()
    private val memberSocialAccountService: MemberSocialAccountService = mock()
    private val cookieService: CookieService = mock()

    private lateinit var service: NaverLoginService

    @BeforeEach
    fun setUp() {
        service = NaverLoginService(
            naverTokenApi = naverTokenApi,
            naverUserInfoApi = naverUserInfoApi,
            memberRepository = memberRepository,
            authService = authService,
            memberSsoRegisterRepository = memberSsoRegisterRepository,
            memberSocialAccountService = memberSocialAccountService,
            cookieService = cookieService,
            clientId = "naver-client-id",
            clientSecret = "naver-client-secret"
        )
    }

    @Test
    fun `setNaverIdToMember delegates social account link`() {
        val member = memberWithId(1L)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        stubNaverApis(naverId = "naver-123")

        service.setNaverIdToMember(
            code = "code-1",
            state = "encoded-state",
            loginMember = LoginMember(id = 1L, name = "tester")
        )

        verify(naverTokenApi).getAccessToken(
            grantType = "authorization_code",
            clientId = "naver-client-id",
            clientSecret = "naver-client-secret",
            code = "code-1",
            state = "encoded-state"
        )
        verify(memberSocialAccountService).link(member, SsoType.NAVER, "naver-123")
    }

    @Test
    fun `setNaverIdToMember throws when member not found`() {
        whenever(memberRepository.findById(1L)).thenReturn(Optional.empty())
        stubNaverApis(naverId = "naver-123")

        assertThrows<NoSuchElementException> {
            service.setNaverIdToMember(
                code = "code-1",
                state = "encoded-state",
                loginMember = LoginMember(id = 1L, name = "tester")
            )
        }
    }

    @Test
    fun `setNaverIdToMember propagates social account link exception`() {
        val member = memberWithId(1L)
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        whenever(memberSocialAccountService.link(member, SsoType.NAVER, "naver-123"))
            .thenThrow(SocialAccountAlreadyLinkedException(SsoType.NAVER))
        stubNaverApis(naverId = "naver-123")

        val exception = assertThrows<SocialAccountAlreadyLinkedException> {
            service.setNaverIdToMember(
                code = "code-1",
                state = "encoded-state",
                loginMember = LoginMember(id = 1L, name = "tester")
            )
        }
        assertThat(exception.provider).isEqualTo(SsoType.NAVER)
    }

    @Test
    fun `login returns success redirect for existing member`() {
        val member = memberWithId(10L)
        val redirectTarget = "/todo?view=mine"
        whenever(memberSocialAccountService.findMemberByProviderAndSocialId(SsoType.NAVER, "naver-123")).thenReturn(member)
        stubNaverApis(naverId = "naver-123")
        whenever(authService.getTokenResponseByMemberId(eq(10L), any())).thenReturn(
            TokenResponse(accessToken = "access", refreshToken = "refresh", expiresIn = 3600)
        )

        val request = MockHttpServletRequest()
        val response = MockHttpServletResponse()
        val result = service.login(
            req = request,
            resp = response,
            code = "code-1",
            state = "encoded-state",
            callbackUrl = "https://client/callback",
            redirectTarget = redirectTarget
        )

        assertThat(result.statusCode).isEqualTo(HttpStatus.FOUND)
        assertThat(result.headers.location?.toString()).isEqualTo(
            "https://client/callback#login=success&redirect=%2Ftodo%3Fview%3Dmine"
        )
        verify(cookieService).setTokenCookies(response, "access", "refresh")
        verify(memberSsoRegisterRepository, never()).save(any())
    }

    @Test
    fun `login returns sso required for new member`() {
        val redirectTarget = "/todo?view=mine"
        whenever(memberSocialAccountService.findMemberByProviderAndSocialId(SsoType.NAVER, "naver-999")).thenReturn(null)
        stubNaverApis(naverId = "naver-999")
        whenever(memberSsoRegisterRepository.save(any())).thenAnswer { it.arguments[0] as MemberSsoRegister }

        val request = MockHttpServletRequest()
        val response = MockHttpServletResponse()
        val result = service.login(
            req = request,
            resp = response,
            code = "code-2",
            state = "encoded-state",
            callbackUrl = "https://client/callback",
            redirectTarget = redirectTarget
        )

        val captor = argumentCaptor<MemberSsoRegister>()
        verify(memberSsoRegisterRepository).save(captor.capture())
        val saved = captor.firstValue

        assertThat(result.statusCode).isEqualTo(HttpStatus.FOUND)
        assertThat(result.headers.location?.toString()).isEqualTo(
            "https://client/callback#error=sso_required&uuid=${saved.uuid}&redirect=%2Ftodo%3Fview%3Dmine"
        )
        assertThat(saved.ssoType).isEqualTo(SsoType.NAVER)
        assertThat(saved.ssoId).isEqualTo("naver-999")
        verify(cookieService, never()).setTokenCookies(any(), any(), any())
        verify(authService, never()).getTokenResponseByMemberId(any(), any())
    }

    private fun stubNaverApis(naverId: String) {
        whenever(
            naverTokenApi.getAccessToken(
                grantType = any(),
                clientId = any(),
                clientSecret = any(),
                code = any(),
                state = any()
            )
        ).thenReturn(
            NaverTokenResponse(
                accessToken = "access-token",
                refreshToken = "refresh-token",
                tokenType = "bearer",
                expiresIn = "3600"
            )
        )
        whenever(naverUserInfoApi.getUserInfo("Bearer access-token")).thenReturn(
            NaverUserInfoResponse(
                resultCode = "00",
                message = "success",
                response = NaverUserInfoPayload(id = naverId)
            )
        )
    }

    private fun memberWithId(id: Long): Member {
        val member = Member("user", "user@duty.park", "pass")
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(member, id)
        return member
    }
}
