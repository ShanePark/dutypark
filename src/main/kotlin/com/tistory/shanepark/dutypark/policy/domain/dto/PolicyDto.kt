package com.tistory.shanepark.dutypark.policy.domain.dto

import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import java.time.LocalDate

data class PolicyDto(
    val policyType: PolicyType,
    val version: String,
    val content: String,
    val effectiveDate: LocalDate
) {
    companion object {
        fun from(entity: PolicyVersion): PolicyDto {
            return PolicyDto(
                policyType = entity.policyType,
                version = entity.version,
                content = entity.content,
                effectiveDate = entity.effectiveDate
            )
        }
    }
}
