package com.tistory.shanepark.dutypark.consent.repository

import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEvent
import org.springframework.data.jpa.repository.JpaRepository

interface AiScheduleParsingConsentEventRepository : JpaRepository<AiScheduleParsingConsentEvent, Long> {
    fun findTopByMember_IdOrderByCreatedAtDescIdDesc(memberId: Long): AiScheduleParsingConsentEvent?
}
