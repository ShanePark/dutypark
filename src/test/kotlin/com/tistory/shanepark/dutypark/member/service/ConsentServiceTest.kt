package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.member.repository.MemberConsentRepository
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired

class ConsentServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var consentService: ConsentService

    @Autowired
    lateinit var memberConsentRepository: MemberConsentRepository

    @Test
    fun `recordConsent stores consent with truncated user agent`() {
        val longUserAgent = "a".repeat(600)

        consentService.recordConsent(
            member = TestData.member,
            policyType = PolicyType.TERMS,
            consentVersion = "1.0",
            ipAddress = "127.0.0.1",
            userAgent = longUserAgent
        )

        val saved = memberConsentRepository.findAll().single()
        assertThat(saved.member.id).isEqualTo(TestData.member.id)
        assertThat(saved.policyType).isEqualTo(PolicyType.TERMS)
        assertThat(saved.consentVersion).isEqualTo("1.0")
        assertThat(saved.ipAddress).isEqualTo("127.0.0.1")
        assertThat(saved.userAgent).hasSize(500)
    }
}
