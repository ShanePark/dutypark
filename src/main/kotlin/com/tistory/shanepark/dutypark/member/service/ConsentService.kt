package com.tistory.shanepark.dutypark.member.service

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
    }
}
