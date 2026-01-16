package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberConsent
import com.tistory.shanepark.dutypark.member.repository.MemberConsentRepository
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.verify

@ExtendWith(MockitoExtension::class)
class ConsentServiceTest {

    @Mock
    private lateinit var memberConsentRepository: MemberConsentRepository

    @InjectMocks
    private lateinit var consentService: ConsentService

    @Test
    fun `recordConsent stores consent with truncated user agent`() {
        // Given
        val member = Member(name = "TestUser", email = "test@test.com", password = "password")
        val longUserAgent = "a".repeat(600)

        // When
        consentService.recordConsent(
            member = member,
            policyType = PolicyType.TERMS,
            consentVersion = "1.0",
            ipAddress = "127.0.0.1",
            userAgent = longUserAgent
        )

        // Then
        argumentCaptor<MemberConsent>().apply {
            verify(memberConsentRepository).save(capture())
            val savedConsent = firstValue
            assertThat(savedConsent.member).isEqualTo(member)
            assertThat(savedConsent.policyType).isEqualTo(PolicyType.TERMS)
            assertThat(savedConsent.consentVersion).isEqualTo("1.0")
            assertThat(savedConsent.ipAddress).isEqualTo("127.0.0.1")
            assertThat(savedConsent.userAgent).hasSize(500)
        }
    }
}
