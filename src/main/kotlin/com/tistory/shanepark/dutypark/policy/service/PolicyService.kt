package com.tistory.shanepark.dutypark.policy.service

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class PolicyService(
    private val policyVersionRepository: PolicyVersionRepository
) {

    fun getCurrentPolicy(policyType: PolicyType): PolicyVersion? {
        return policyVersionRepository.findTopByPolicyTypeOrderByEffectiveDateDesc(policyType)
    }

    fun getPolicy(policyType: PolicyType, version: String): PolicyVersion? {
        return policyVersionRepository.findByPolicyTypeAndVersion(policyType, version)
    }
}
