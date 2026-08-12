package com.tistory.shanepark.dutypark.member.accountdeletion.service

import org.springframework.stereotype.Service

/**
 * Revokes provider-side credentials before local social-account rows disappear.
 *
 * Kakao and Naver currently persist only their stable social identifiers, not a
 * credential that can be revoked later, so their current implementation is an
 * intentional no-op. Sign in with Apple must replace this behavior with a
 * durable credential snapshot and a retryable revoke call before local cleanup.
 */
fun interface AccountDeletionExternalAccountRevoker {
    fun revoke(memberIds: List<Long>)
}

@Service
class CurrentSocialAccountRevoker : AccountDeletionExternalAccountRevoker {
    override fun revoke(memberIds: List<Long>) = Unit
}
