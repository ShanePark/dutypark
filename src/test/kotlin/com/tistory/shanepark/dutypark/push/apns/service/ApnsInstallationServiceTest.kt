package com.tistory.shanepark.dutypark.push.apns.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.domain.entity.RefreshToken
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.mockito.junit.jupiter.MockitoExtension
import org.springframework.test.util.ReflectionTestUtils
import java.time.LocalDateTime

@ExtendWith(MockitoExtension::class)
class ApnsInstallationServiceTest {
    private val repository: ApnsInstallationRepository = mock()
    private val refreshTokenRepository: RefreshTokenRepository = mock()
    private val service = ApnsInstallationService(repository, refreshTokenRepository)

    @Test
    fun `register stores a new device token for refresh session`() {
        val member = Member("member", "member@duty.park", "password")
        val refreshToken = validRefreshToken(member, memberId = 1L)
        whenever(refreshTokenRepository.findByToken("refresh-token")).thenReturn(refreshToken)
        whenever(repository.findByDeviceToken("device-token")).thenReturn(null)

        service.register(loginMember(1L), "refresh-token", " device-token ", sandbox = true)

        val captor = argumentCaptor<ApnsInstallation>()
        verify(repository).save(captor.capture())
        assertThat(captor.firstValue.refreshToken).isSameAs(refreshToken)
        assertThat(captor.firstValue.deviceToken).isEqualTo("device-token")
        assertThat(captor.firstValue.sandbox).isTrue()
    }

    @Test
    fun `register moves an existing device token to current refresh session`() {
        val previousMember = Member("previous", "previous@duty.park", "password")
        val currentMember = Member("current", "current@duty.park", "password")
        val previousRefreshToken = validRefreshToken(previousMember, memberId = 1L)
        val currentRefreshToken = validRefreshToken(currentMember, memberId = 2L)
        val installation = ApnsInstallation(previousRefreshToken, "device-token")
        whenever(refreshTokenRepository.findByToken("current-refresh-token")).thenReturn(currentRefreshToken)
        whenever(repository.findByDeviceToken("device-token")).thenReturn(installation)

        service.register(loginMember(2L), "current-refresh-token", "device-token", sandbox = false)

        assertThat(installation.refreshToken).isSameAs(currentRefreshToken)
        assertThat(installation.sandbox).isFalse()
        verify(repository).save(installation)
    }

    @Test
    fun `unregister only removes matching refresh session installation`() {
        val refreshToken = validRefreshToken(
            Member("member", "member@duty.park", "password"),
            memberId = 1L,
            refreshTokenId = 10L,
        )
        whenever(refreshTokenRepository.findByToken("refresh-token")).thenReturn(refreshToken)
        whenever(repository.deleteByRefreshTokenIdAndDeviceToken(10L, "device-token")).thenReturn(1)

        assertThat(service.unregister(loginMember(1L), "refresh-token", " device-token ")).isTrue()
        verify(repository).deleteByRefreshTokenIdAndDeviceToken(10L, "device-token")
    }

    @Test
    fun `impersonation keeps installation on original refresh session`() {
        val originalMember = Member("manager", "manager@duty.park", "password")
        val refreshToken = validRefreshToken(originalMember, memberId = 1L)
        whenever(refreshTokenRepository.findByToken("refresh-token")).thenReturn(refreshToken)
        whenever(repository.findByDeviceToken("device-token")).thenReturn(null)

        service.register(
            loginMember = LoginMember(
                id = 2L,
                name = "managed",
                isImpersonating = true,
                originalMemberId = 1L,
            ),
            refreshTokenValue = "refresh-token",
            deviceToken = "device-token",
            sandbox = true,
        )

        val captor = argumentCaptor<ApnsInstallation>()
        verify(repository).save(captor.capture())
        assertThat(captor.firstValue.refreshToken).isSameAs(refreshToken)
    }

    @Test
    fun `register rejects refresh session owned by another member`() {
        val member = Member("member", "member@duty.park", "password")
        val refreshToken = validRefreshToken(member, memberId = 1L)
        whenever(refreshTokenRepository.findByToken("refresh-token")).thenReturn(refreshToken)

        assertThatThrownBy {
            service.register(loginMember(2L), "refresh-token", "device-token", sandbox = false)
        }.isInstanceOf(AuthException::class.java)
    }

    private fun validRefreshToken(
        member: Member,
        memberId: Long,
        refreshTokenId: Long = 100L + memberId,
    ): RefreshToken {
        ReflectionTestUtils.setField(member, "id", memberId)
        return RefreshToken(
            member = member,
            validUntil = LocalDateTime.now().plusDays(1),
            remoteAddr = null,
            userAgent = null,
        ).also { ReflectionTestUtils.setField(it, "id", refreshTokenId) }
    }

    private fun loginMember(id: Long) = LoginMember(id = id, name = "member-$id")
}
