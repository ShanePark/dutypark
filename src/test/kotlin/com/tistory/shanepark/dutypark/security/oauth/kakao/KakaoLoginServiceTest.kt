package com.tistory.shanepark.dutypark.security.oauth.kakao

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSsoRegister
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSsoRegisterRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.dto.TokenResponse
import com.tistory.shanepark.dutypark.security.service.AuthService
import com.tistory.shanepark.dutypark.security.service.CookieService
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mockito.never
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.http.HttpStatus
import org.springframework.mock.web.MockHttpServletRequest
import org.springframework.mock.web.MockHttpServletResponse
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class KakaoLoginServiceTest {

    private val kakaoTokenApi: KakaoTokenApi = mock()
    private val kakaoUserInfoApi: KakaoUserInfoApi = mock()
    private val memberRepository: MemberRepository = mock()
    private val authService: AuthService = mock()
    private val memberSsoRegisterRepository: MemberSsoRegisterRepository = mock()
    private val cookieService: CookieService = mock()

    private lateinit var service: KakaoLoginService

    @BeforeEach
    fun setUp() {
        service = KakaoLoginService(
            kakaoTokenApi = kakaoTokenApi,
            kakaoUserInfoApi = kakaoUserInfoApi,
            memberRepository = memberRepository,
            authService = authService,
            memberSsoRegisterRepository = memberSsoRegisterRepository,
            cookieService = cookieService,
            restApiKey = "rest-key"
        )
    }

    @Test
    fun `setKakaoIdToMember sets kakao id`() {
        val member = Member("tester", "tester@duty.park", "pass")
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(member))
        stubKakaoApis(kakaoId = 123L)

        service.setKakaoIdToMember(
            code = "code-1",
            redirectUrl = "https://auth/callback",
            loginMember = LoginMember(id = 1L, name = "tester")
        )

        assertThat(member.kakaoId).isEqualTo("123")
        verify(kakaoTokenApi).getAccessToken(
            grantType = "authorization_code",
            clientId = "rest-key",
            redirectUri = "https://auth/callback",
            code = "code-1"
        )
    }

    @Test
    fun `setKakaoIdToMember throws when member not found`() {
        whenever(memberRepository.findById(1L)).thenReturn(Optional.empty())
        stubKakaoApis(kakaoId = 123L)

        assertThrows<NoSuchElementException> {
            service.setKakaoIdToMember(
                code = "code-1",
                redirectUrl = "https://auth/callback",
                loginMember = LoginMember(id = 1L, name = "tester")
            )
        }
    }

    @Test
    fun `login returns success redirect for existing member`() {
        val member = memberWithId(10L)
        whenever(memberRepository.findMemberByKakaoId("123")).thenReturn(member)
        stubKakaoApis(kakaoId = 123L)
        whenever(authService.getTokenResponseByMemberId(org.mockito.kotlin.eq(10L), org.mockito.kotlin.any())).thenReturn(
            TokenResponse(accessToken = "access", refreshToken = "refresh", expiresIn = 3600)
        )

        val request = MockHttpServletRequest()
        val response = MockHttpServletResponse()
        val result = service.login(
            req = request,
            resp = response,
            code = "code-1",
            redirectUrl = "https://auth/callback",
            callbackUrl = "https://client/callback"
        )

        assertThat(result.statusCode).isEqualTo(HttpStatus.FOUND)
        assertThat(result.headers.location?.toString()).isEqualTo("https://client/callback#login=success")
        verify(cookieService).setTokenCookies(response, "access", "refresh")
        verify(memberSsoRegisterRepository, never()).save(org.mockito.kotlin.any())
    }

    @Test
    fun `login returns sso required for new member`() {
        whenever(memberRepository.findMemberByKakaoId("999")).thenReturn(null)
        stubKakaoApis(kakaoId = 999L)
        whenever(memberSsoRegisterRepository.save(org.mockito.kotlin.any())).thenAnswer { it.arguments[0] as MemberSsoRegister }

        val request = MockHttpServletRequest()
        val response = MockHttpServletResponse()
        val result = service.login(
            req = request,
            resp = response,
            code = "code-2",
            redirectUrl = "https://auth/callback",
            callbackUrl = "https://client/callback"
        )

        val captor = argumentCaptor<MemberSsoRegister>()
        verify(memberSsoRegisterRepository).save(captor.capture())
        val saved = captor.firstValue

        assertThat(result.statusCode).isEqualTo(HttpStatus.FOUND)
        assertThat(result.headers.location?.toString()).isEqualTo(
            "https://client/callback#error=sso_required&uuid=${saved.uuid}"
        )
        assertThat(saved.ssoType).isEqualTo(SsoType.KAKAO)
        assertThat(saved.ssoId).isEqualTo("999")
        verify(cookieService, never()).setTokenCookies(org.mockito.kotlin.any(), org.mockito.kotlin.any(), org.mockito.kotlin.any())
        verify(authService, never()).getTokenResponseByMemberId(org.mockito.kotlin.any(), org.mockito.kotlin.any())
    }

    private fun stubKakaoApis(kakaoId: Long) {
        whenever(
            kakaoTokenApi.getAccessToken(
                grantType = org.mockito.kotlin.any(),
                clientId = org.mockito.kotlin.any(),
                redirectUri = org.mockito.kotlin.any(),
                code = org.mockito.kotlin.any()
            )
        ).thenReturn(
            KakaoTokenResponse(
                accessToken = "access-token",
                tokenType = "bearer",
                refreshToken = "refresh-token",
                expiresIn = 3600,
                refreshTokenExpiresIn = 7200
            )
        )
        whenever(kakaoUserInfoApi.getUserInfo("Bearer access-token")).thenReturn(
            KakaoUserInfoResponse(
                id = kakaoId,
                connectedAt = "2025-01-01T00:00:00Z"
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
