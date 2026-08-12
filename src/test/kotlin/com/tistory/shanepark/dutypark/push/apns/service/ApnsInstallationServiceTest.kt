package com.tistory.shanepark.dutypark.push.apns.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.mockito.junit.jupiter.MockitoExtension

@ExtendWith(MockitoExtension::class)
class ApnsInstallationServiceTest {
    private val repository: ApnsInstallationRepository = mock()
    private val memberRepository: MemberRepository = mock()
    private val service = ApnsInstallationService(repository, memberRepository)

    @Test
    fun `register stores a new device token for member`() {
        val member = Member("member", "member@duty.park", "password")
        whenever(memberRepository.getReferenceById(1L)).thenReturn(member)
        whenever(repository.findByDeviceToken("device-token")).thenReturn(null)

        service.register(1L, " device-token ", sandbox = true)

        val captor = argumentCaptor<ApnsInstallation>()
        verify(repository).save(captor.capture())
        assertThat(captor.firstValue.member).isSameAs(member)
        assertThat(captor.firstValue.deviceToken).isEqualTo("device-token")
        assertThat(captor.firstValue.sandbox).isTrue()
    }

    @Test
    fun `register moves an existing device token to current member`() {
        val previousMember = Member("previous", "previous@duty.park", "password")
        val currentMember = Member("current", "current@duty.park", "password")
        val installation = ApnsInstallation(previousMember, "device-token")
        whenever(memberRepository.getReferenceById(2L)).thenReturn(currentMember)
        whenever(repository.findByDeviceToken("device-token")).thenReturn(installation)

        service.register(2L, "device-token", sandbox = false)

        assertThat(installation.member).isSameAs(currentMember)
        assertThat(installation.sandbox).isFalse()
        verify(repository).save(installation)
    }

    @Test
    fun `unregister only removes matching member installation`() {
        whenever(repository.deleteByMemberIdAndDeviceToken(1L, "device-token")).thenReturn(1)

        assertThat(service.unregister(1L, " device-token ")).isTrue()
        verify(repository).deleteByMemberIdAndDeviceToken(1L, "device-token")
    }
}
