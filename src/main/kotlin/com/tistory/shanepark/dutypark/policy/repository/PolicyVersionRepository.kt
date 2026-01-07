package com.tistory.shanepark.dutypark.policy.repository

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import org.springframework.data.jpa.repository.JpaRepository

interface PolicyVersionRepository : JpaRepository<PolicyVersion, Long> {
    fun findByPolicyTypeAndVersion(policyType: PolicyType, version: String): PolicyVersion?
    fun findTopByPolicyTypeOrderByEffectiveDateDesc(policyType: PolicyType): PolicyVersion?
}
