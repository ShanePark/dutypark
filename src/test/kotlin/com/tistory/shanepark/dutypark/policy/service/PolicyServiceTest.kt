package com.tistory.shanepark.dutypark.policy.service

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.whenever
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId
import java.time.ZoneOffset

@ExtendWith(MockitoExtension::class)
class PolicyServiceTest {

    private val today = LocalDate.of(2026, 8, 14)
    private val seoul = ZoneId.of("Asia/Seoul")
    private val clock = Clock.fixed(today.atStartOfDay(seoul).toInstant(), ZoneOffset.UTC)

    @Mock
    lateinit var policyVersionRepository: PolicyVersionRepository

    lateinit var policyService: PolicyService

    @BeforeEach
    fun setUp() {
        policyService = PolicyService(policyVersionRepository, clock)
    }

    @Test
    fun `getCurrentPolicy returns latest by effective date`() {
        val latestPolicy = PolicyVersion(
            policyType = PolicyType.TERMS,
            version = "2.0",
            content = "terms-v2",
            effectiveDate = LocalDate.of(2025, 1, 1)
        )
        whenever(
            policyVersionRepository.findTopByPolicyTypeAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
                PolicyType.TERMS,
                today,
            )
        )
            .thenReturn(latestPolicy)

        val current = policyService.getCurrentPolicy(PolicyType.TERMS)

        assertThat(current?.version).isEqualTo("2.0")
    }

    @Test
    fun `getCurrentPolicy returns null when no policy`() {
        whenever(
            policyVersionRepository.findTopByPolicyTypeAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
                PolicyType.PRIVACY,
                today,
            )
        )
            .thenReturn(null)

        val current = policyService.getCurrentPolicy(PolicyType.PRIVACY)

        assertThat(current).isNull()
    }

}
