package com.tistory.shanepark.dutypark.policy.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDate

class PolicyServiceTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var policyService: PolicyService

    @Autowired
    lateinit var policyVersionRepository: PolicyVersionRepository

    @Test
    fun `getCurrentPolicy returns latest by effective date`() {
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.TERMS,
                version = "1.0",
                content = "terms-v1",
                effectiveDate = LocalDate.of(2024, 1, 1)
            )
        )
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.TERMS,
                version = "2.0",
                content = "terms-v2",
                effectiveDate = LocalDate.of(2025, 1, 1)
            )
        )

        val current = policyService.getCurrentPolicy(PolicyType.TERMS)

        assertThat(current?.version).isEqualTo("2.0")
    }

    @Test
    fun `getCurrentPolicy returns null when no policy`() {
        val current = policyService.getCurrentPolicy(PolicyType.PRIVACY)

        assertThat(current).isNull()
    }

    @Test
    fun `getPolicy returns policy by version`() {
        policyVersionRepository.save(
            PolicyVersion(
                policyType = PolicyType.PRIVACY,
                version = "1.0",
                content = "privacy-v1",
                effectiveDate = LocalDate.of(2024, 6, 1)
            )
        )

        val policy = policyService.getPolicy(PolicyType.PRIVACY, "1.0")
        val missing = policyService.getPolicy(PolicyType.PRIVACY, "missing")

        assertThat(policy?.version).isEqualTo("1.0")
        assertThat(missing).isNull()
    }
}
