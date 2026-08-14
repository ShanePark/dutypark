package com.tistory.shanepark.dutypark.policy.service

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.repository.PolicyVersionRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.Clock
import java.time.LocalDate
import java.time.ZoneId

@Service
@Transactional(readOnly = true)
class PolicyService(
    private val policyVersionRepository: PolicyVersionRepository,
    private val clock: Clock,
) {

    fun getCurrentPolicy(policyType: PolicyType): PolicyVersion? {
        return policyVersionRepository.findTopByPolicyTypeAndEffectiveDateLessThanEqualOrderByEffectiveDateDesc(
            policyType = policyType,
            effectiveDate = LocalDate.now(clock.withZone(SEOUL)),
        )
    }

    companion object {
        private val SEOUL: ZoneId = ZoneId.of("Asia/Seoul")
    }
}
