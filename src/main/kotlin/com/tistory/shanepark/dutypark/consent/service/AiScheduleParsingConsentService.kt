package com.tistory.shanepark.dutypark.consent.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEvent
import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEventType
import com.tistory.shanepark.dutypark.consent.dto.AiScheduleParsingConsentResponse
import com.tistory.shanepark.dutypark.consent.repository.AiScheduleParsingConsentEventRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.policy.domain.dto.PolicyDto
import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.service.PolicyService
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class AiScheduleParsingConsentService(
    private val consentEventRepository: AiScheduleParsingConsentEventRepository,
    private val memberRepository: MemberRepository,
    private val policyService: PolicyService,
) {
    private val log = logger()

    fun getConsent(memberId: Long): AiScheduleParsingConsentResponse {
        val currentPolicy = requireCurrentPolicy()
        return response(currentPolicy, consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(memberId))
    }

    fun hasCurrentConsent(memberId: Long): Boolean {
        val currentPolicy = policyService.getCurrentPolicy(PolicyType.AI_SCHEDULE_PARSING) ?: return false
        val latestEvent = consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(memberId) ?: return false
        return latestEvent.eventType == AiScheduleParsingConsentEventType.GRANTED &&
            latestEvent.policyVersion == currentPolicy.version
    }

    @Transactional
    fun updateConsent(
        memberId: Long,
        consented: Boolean,
        policyVersion: String?,
        ipAddress: String?,
        userAgent: String?,
    ): AiScheduleParsingConsentResponse {
        val currentPolicy = requireCurrentPolicy()
        if (consented && policyVersion != currentPolicy.version) {
            throw BadRequestException("consent.aiScheduleParsing.policyVersionMismatch")
        }

        val member = memberRepository.findMemberWithTeamForUpdate(memberId)
            .orElseThrow { NoSuchElementException("consent.member.notFound") }
        val latestEvent = consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(memberId)
        val requestedType = if (consented) AiScheduleParsingConsentEventType.GRANTED
        else AiScheduleParsingConsentEventType.REVOKED
        val isSameState = latestEvent?.eventType == requestedType &&
            (!consented || latestEvent.policyVersion == currentPolicy.version)
        if (isSameState) {
            return response(currentPolicy, latestEvent)
        }

        val savedEvent = consentEventRepository.save(
            AiScheduleParsingConsentEvent(
                member = member,
                eventType = requestedType,
                policyVersion = currentPolicy.version.takeIf { consented },
                ipAddress = ipAddress?.take(45),
                userAgent = userAgent?.take(500),
            )
        )
        log.info(
            "AI schedule parsing consent changed: memberId={}, eventType={}, policyVersion={}",
            memberId, requestedType, savedEvent.policyVersion,
        )
        return response(currentPolicy, savedEvent)
    }

    private fun requireCurrentPolicy(): PolicyVersion =
        policyService.getCurrentPolicy(PolicyType.AI_SCHEDULE_PARSING)
            ?: throw NoSuchElementException("consent.aiScheduleParsing.policyUnavailable")

    private fun response(
        currentPolicy: PolicyVersion,
        latestEvent: AiScheduleParsingConsentEvent?,
    ): AiScheduleParsingConsentResponse {
        val consented = latestEvent?.eventType == AiScheduleParsingConsentEventType.GRANTED
        return AiScheduleParsingConsentResponse(
            policy = PolicyDto.from(currentPolicy),
            consented = consented,
            currentPolicyVersion = currentPolicy.version,
            consentVersion = latestEvent?.policyVersion,
            needsRenewal = consented && latestEvent.policyVersion != currentPolicy.version,
            consentedAt = latestEvent?.createdAt?.takeIf { consented },
            revokedAt = latestEvent?.createdAt?.takeIf { !consented },
        )
    }
}
