package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberSocialAccount
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.exception.SocialAccountUnlinkException
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.oauth.SocialAccountAlreadyLinkedException
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.any
import org.mockito.kotlin.argThat
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.dao.DataIntegrityViolationException
import org.springframework.test.util.ReflectionTestUtils
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class MemberSocialAccountServiceTest {

    private val memberSocialAccountRepository: MemberSocialAccountRepository = mock()
    private val memberRepository: MemberRepository = mock()

    private lateinit var service: MemberSocialAccountService

    @BeforeEach
    fun setUp() {
        service = MemberSocialAccountService(memberRepository, memberSocialAccountRepository)
    }

    @Test
    fun `findMemberByProviderAndSocialId returns linked member`() {
        val member = memberWithId(1L)
        whenever(memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, "kakao-1"))
            .thenReturn(MemberSocialAccount(member = member, provider = SsoType.KAKAO, socialId = "kakao-1"))

        val found = service.findMemberByProviderAndSocialId(SsoType.KAKAO, "kakao-1")

        assertThat(found?.id).isEqualTo(member.id)
    }

    @Test
    fun `link creates social account when no link exists`() {
        val member = memberWithId(1L)
        whenever(memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, "kakao-1")).thenReturn(null)
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).thenReturn(null)
        whenever(memberSocialAccountRepository.saveAndFlush(any())).thenAnswer { it.arguments[0] }

        service.link(member, SsoType.KAKAO, "kakao-1")

        verify(memberSocialAccountRepository).saveAndFlush(
            argThat<MemberSocialAccount> {
                this.member.id == member.id && this.provider == SsoType.KAKAO && this.socialId == "kakao-1"
            }
        )
    }

    @Test
    fun `link is idempotent for same member provider and social id`() {
        val member = memberWithId(1L)
        val existing = MemberSocialAccount(member = member, provider = SsoType.NAVER, socialId = "naver-1")
        whenever(memberSocialAccountRepository.findByProviderAndSocialId(SsoType.NAVER, "naver-1")).thenReturn(existing)

        service.link(member, SsoType.NAVER, "naver-1")

        verify(memberSocialAccountRepository, never()).saveAndFlush(any())
    }

    @Test
    fun `link throws when social id is already linked to another member`() {
        val member = memberWithId(1L)
        val otherMember = memberWithId(2L)
        whenever(memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, "kakao-2"))
            .thenReturn(MemberSocialAccount(member = otherMember, provider = SsoType.KAKAO, socialId = "kakao-2"))

        val exception = assertThrows<SocialAccountAlreadyLinkedException> {
            service.link(member, SsoType.KAKAO, "kakao-2")
        }

        assertThat(exception.provider).isEqualTo(SsoType.KAKAO)
    }

    @Test
    fun `link throws when member already has another social id for same provider`() {
        val member = memberWithId(1L)
        whenever(memberSocialAccountRepository.findByProviderAndSocialId(SsoType.NAVER, "naver-2")).thenReturn(null)
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.NAVER))
            .thenReturn(MemberSocialAccount(member = member, provider = SsoType.NAVER, socialId = "naver-1"))

        val exception = assertThrows<SocialAccountAlreadyLinkedException> {
            service.link(member, SsoType.NAVER, "naver-2")
        }

        assertThat(exception.provider).isEqualTo(SsoType.NAVER)
    }

    @Test
    fun `link throws social linked exception when repository save fails`() {
        val member = memberWithId(1L)
        whenever(memberSocialAccountRepository.findByProviderAndSocialId(SsoType.KAKAO, "kakao-3")).thenReturn(null)
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).thenReturn(null)
        whenever(memberSocialAccountRepository.saveAndFlush(any()))
            .thenThrow(DataIntegrityViolationException("duplicate"))

        val exception = assertThrows<SocialAccountAlreadyLinkedException> {
            service.link(member, SsoType.KAKAO, "kakao-3")
        }

        assertThat(exception.provider).isEqualTo(SsoType.KAKAO)
    }

    @Test
    fun `findProviderMapByMemberIds groups social ids by member and provider`() {
        val member1 = memberWithId(1L)
        val member2 = memberWithId(2L)
        whenever(memberSocialAccountRepository.findAllByMemberIdIn(setOf(1L, 2L))).thenReturn(
            listOf(
                MemberSocialAccount(member = member1, provider = SsoType.KAKAO, socialId = "kakao-1"),
                MemberSocialAccount(member = member1, provider = SsoType.NAVER, socialId = "naver-1"),
                MemberSocialAccount(member = member2, provider = SsoType.KAKAO, socialId = "kakao-2"),
            )
        )

        val found = service.findProviderMapByMemberIds(setOf(1L, 2L))

        assertThat(found[1L]?.get(SsoType.KAKAO)).isEqualTo("kakao-1")
        assertThat(found[1L]?.get(SsoType.NAVER)).isEqualTo("naver-1")
        assertThat(found[2L]?.get(SsoType.KAKAO)).isEqualTo("kakao-2")
    }

    @Test
    fun `unlink is idempotent when provider is not linked`() {
        val member = memberWithId(1L)
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).thenReturn(null)

        service.unlink(loginMember(), SsoType.KAKAO)

        verify(memberRepository).findMemberWithTeamForUpdate(1L)
        verify(memberSocialAccountRepository, never()).delete(any())
    }

    @Test
    fun `unlink rejects removing sole social account even when password exists`() {
        val member = memberWithId(1L)
        val kakao = socialAccount(member, SsoType.KAKAO)
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).thenReturn(kakao)
        whenever(memberSocialAccountRepository.findAllByMemberIdIn(listOf(1L))).thenReturn(listOf(kakao))

        val exception = assertThrows<SocialAccountUnlinkException> {
            service.unlink(loginMember(), SsoType.KAKAO)
        }

        assertThat(exception.errorCode).isEqualTo(409)
        assertThat(exception.message).isEqualTo("member.social.unlink.lastAuthenticationMethod")
        verify(memberSocialAccountRepository, never()).delete(any())
    }

    @Test
    fun `unlink rejects removing last authentication method`() {
        val member = memberWithId(1L).also { it.password = " " }
        val kakao = socialAccount(member, SsoType.KAKAO)
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).thenReturn(kakao)
        whenever(memberSocialAccountRepository.findAllByMemberIdIn(listOf(1L))).thenReturn(listOf(kakao))

        val exception = assertThrows<SocialAccountUnlinkException> {
            service.unlink(loginMember(), SsoType.KAKAO)
        }

        assertThat(exception.errorCode).isEqualTo(409)
        assertThat(exception.message).isEqualTo("member.social.unlink.lastAuthenticationMethod")
        verify(memberSocialAccountRepository, never()).delete(any())
    }

    @Test
    fun `unlink allows removing one social account when another remains`() {
        val member = memberWithId(1L).also { it.password = null }
        val kakao = socialAccount(member, SsoType.KAKAO)
        val naver = socialAccount(member, SsoType.NAVER)
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(memberSocialAccountRepository.findByMemberAndProvider(member, SsoType.KAKAO)).thenReturn(kakao)
        whenever(memberSocialAccountRepository.findAllByMemberIdIn(listOf(1L))).thenReturn(listOf(kakao, naver))

        service.unlink(loginMember(), SsoType.KAKAO)

        verify(memberSocialAccountRepository).delete(kakao)
    }

    @Test
    fun `unlink rejects impersonation before acquiring member lock`() {
        val impersonating = loginMember().copy(isImpersonating = true, originalMemberId = 2L)

        val exception = assertThrows<SocialAccountUnlinkException> {
            service.unlink(impersonating, SsoType.NAVER)
        }

        assertThat(exception.errorCode).isEqualTo(403)
        assertThat(exception.message).isEqualTo("member.social.unlink.impersonationForbidden")
        verify(memberRepository, never()).findMemberWithTeamForUpdate(any())
        verify(memberSocialAccountRepository, never()).delete(any())
    }

    private fun loginMember() = LoginMember(id = 1L, name = "user")

    private fun socialAccount(member: Member, provider: SsoType) =
        MemberSocialAccount(member = member, provider = provider, socialId = "${provider.name.lowercase()}-1")

    private fun memberWithId(id: Long): Member {
        val member = Member("user", "user@duty.park", "pass")
        ReflectionTestUtils.setField(member, "id", id)
        return member
    }
}
