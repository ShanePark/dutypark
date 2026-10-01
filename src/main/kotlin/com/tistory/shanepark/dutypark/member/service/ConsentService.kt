package com.tistory.shanepark.dutypark.member.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.entity.MemberConsent
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.member.repository.MemberConsentRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional(readOnly = true)
class ConsentService(
    private val memberConsentRepository: MemberConsentRepository
) {
    private val log = logger()

    @Transactional
    fun recordConsent(
        member: Member,
        policyType: PolicyType,
        consentVersion: String,
        ipAddress: String?,
        userAgent: String?
    ) {
        val consent = MemberConsent(
            member = member,
            policyType = policyType,
            consentVersion = consentVersion,
            ipAddress = ipAddress,
            userAgent = userAgent?.take(500)
        )
        memberConsentRepository.save(consent)
        log.auditEventAfterCommit(
            "consent.recorded", member.toAuditActor(),
            target = mapOf("type" to "MemberConsent", "id" to consent.id, "memberId" to member.id),
            details = mapOf("policyType" to policyType, "consentVersion" to consentVersion),
        )
    }
}
