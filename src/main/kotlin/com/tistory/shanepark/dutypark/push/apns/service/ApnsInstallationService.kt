package com.tistory.shanepark.dutypark.push.apns.service

import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.push.apns.domain.entity.ApnsInstallation
import com.tistory.shanepark.dutypark.push.apns.domain.repository.ApnsInstallationRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional

@Service
@Transactional
class ApnsInstallationService(
    private val apnsInstallationRepository: ApnsInstallationRepository,
    private val memberRepository: MemberRepository,
) {
    fun register(memberId: Long, deviceToken: String, sandbox: Boolean) {
        val normalizedToken = deviceToken.trim()
        val member = memberRepository.getReferenceById(memberId)
        val installation = apnsInstallationRepository.findByDeviceToken(normalizedToken)
            ?.apply {
                this.member = member
                this.sandbox = sandbox
            }
            ?: ApnsInstallation(member = member, deviceToken = normalizedToken, sandbox = sandbox)

        apnsInstallationRepository.save(installation)
    }

    fun unregister(memberId: Long, deviceToken: String): Boolean =
        apnsInstallationRepository.deleteByMemberIdAndDeviceToken(memberId, deviceToken.trim()) > 0
}
