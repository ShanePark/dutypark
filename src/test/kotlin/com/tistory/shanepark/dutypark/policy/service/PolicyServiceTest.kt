package com.tistory.shanepark.dutypark.policy.service

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.InjectMocks
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.whenever
import java.time.LocalDate

@ExtendWith(MockitoExtension::class)
class PolicyServiceTest {

    @Mock
    lateinit var policyVersionRepository: PolicyVersionRepository

    @InjectMocks
    lateinit var policyService: PolicyService

    @Test
    fun `getCurrentPolicy returns latest by effective date`() {
        val latestPolicy = PolicyVersion(
            policyType = PolicyType.TERMS,
            version = "2.0",
            content = "terms-v2",
            effectiveDate = LocalDate.of(2025, 1, 1)
        )
        whenever(policyVersionRepository.findTopByPolicyTypeOrderByEffectiveDateDesc(PolicyType.TERMS))
            .thenReturn(latestPolicy)

        val current = policyService.getCurrentPolicy(PolicyType.TERMS)

        assertThat(current?.version).isEqualTo("2.0")
    }

    @Test
    fun `getCurrentPolicy returns null when no policy`() {
        whenever(policyVersionRepository.findTopByPolicyTypeOrderByEffectiveDateDesc(PolicyType.PRIVACY))
            .thenReturn(null)

        val current = policyService.getCurrentPolicy(PolicyType.PRIVACY)

        assertThat(current).isNull()
    }

    @Test
    fun `getPolicy returns policy by version`() {
        val policy = PolicyVersion(
            policyType = PolicyType.PRIVACY,
            version = "1.0",
            content = "privacy-v1",
            effectiveDate = LocalDate.of(2024, 6, 1)
        )
        whenever(policyVersionRepository.findByPolicyTypeAndVersion(PolicyType.PRIVACY, "1.0"))
            .thenReturn(policy)
        whenever(policyVersionRepository.findByPolicyTypeAndVersion(PolicyType.PRIVACY, "missing"))
            .thenReturn(null)

        val foundPolicy = policyService.getPolicy(PolicyType.PRIVACY, "1.0")
        val missingPolicy = policyService.getPolicy(PolicyType.PRIVACY, "missing")

        assertThat(foundPolicy?.version).isEqualTo("1.0")
        assertThat(missingPolicy).isNull()
    }
}
