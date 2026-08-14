package com.tistory.shanepark.dutypark.member.accountdeletion.service

import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.security.oauth.apple.AppleCredentialService
import org.springframework.stereotype.Service

/**
 * Revokes provider-side credentials before local social-account rows disappear.
 *
 * Kakao and Naver persist only stable identifiers, so they remain intentional
 * no-ops. Apple refresh tokens are retained encrypted and revoked here; a
 * provider failure is propagated so the durable deletion worker can retry.
 */
fun interface AccountDeletionExternalAccountRevoker {
    fun revoke(memberIds: List<Long>)
}

@Service
class CurrentSocialAccountRevoker(
    private val socialAccountRepository: MemberSocialAccountRepository,
    private val appleCredentialService: AppleCredentialService,
) : AccountDeletionExternalAccountRevoker {
    override fun revoke(memberIds: List<Long>) {
        socialAccountRepository.findAllByMemberIdIn(memberIds)
            .filter { it.provider == SsoType.APPLE }
            .forEach { appleCredentialService.revokeAndDelete(it.socialId) }
    }
}
