package com.tistory.shanepark.dutypark.policy.repository

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import org.springframework.data.jpa.repository.JpaRepository
import java.time.LocalDate

interface PolicyVersionRepository : JpaRepository<PolicyVersion, Long> {
    fun findTopByPolicyTypeAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
        policyType: PolicyType,
        effectiveDate: LocalDate,
    ): PolicyVersion?
}
