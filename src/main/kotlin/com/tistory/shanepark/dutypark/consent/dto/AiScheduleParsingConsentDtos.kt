package com.tistory.shanepark.dutypark.consent.dto

import com.tistory.shanepark.dutypark.policy.domain.dto.PolicyDto
import java.time.LocalDateTime

data class AiScheduleParsingConsentResponse(
    val policy: PolicyDto,
    val consented: Boolean,
    val currentPolicyVersion: String,
    val consentVersion: String?,
    val needsRenewal: Boolean,
    val consentedAt: LocalDateTime?,
    val revokedAt: LocalDateTime?,
)

data class UpdateAiScheduleParsingConsentRequest(
    val consented: Boolean,
    val policyVersion: String? = null,
)
