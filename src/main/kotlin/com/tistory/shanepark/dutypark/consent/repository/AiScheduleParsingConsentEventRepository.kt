package com.tistory.shanepark.dutypark.consent.repository

import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEvent
import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEventType
import org.springframework.data.jpa.repository.JpaRepository

interface AiScheduleParsingConsentEventRepository : JpaRepository<AiScheduleParsingConsentEvent, Long> {
    fun findTopByMember_IdOrderByCreatedAtDescIdDesc(memberId: Long): AiScheduleParsingConsentEvent?

    fun existsByMember_IdAndEventTypeAndPolicyVersion(
        memberId: Long,
        eventType: AiScheduleParsingConsentEventType,
        policyVersion: String,
    ): Boolean
}
