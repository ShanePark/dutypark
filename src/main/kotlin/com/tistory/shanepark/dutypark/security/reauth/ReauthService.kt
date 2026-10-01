package com.tistory.shanepark.dutypark.security.reauth

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.common.logging.auditContext
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.security.SecureRandom
import java.time.Clock
import java.time.Duration
import java.util.Base64

@Service
@Transactional
class ReauthService(
    private val reauthProofRepository: ReauthProofRepository,
    private val memberRepository: MemberRepository,
    private val clock: Clock,
) {
    private val log = logger()
    private val secureRandom = SecureRandom()

    fun issue(memberId: Long, purpose: ReauthPurpose): ReauthProofResponse {
        val member = memberRepository.findById(memberId).orElseThrow {
            AuthException("auth.account.inactive")
        }
        if (member.status != MemberStatus.ACTIVE) {
            throw AuthException("auth.account.inactive")
        }
        val proof = randomToken()
        val now = clock.instant()
        reauthProofRepository.save(
            ReauthProof(
                purpose = purpose,
                proofHash = sha256Hex(proof),
                memberId = memberId,
                expiresAt = now.plus(PROOF_TTL),
                createdAt = now,
            )
        )
        log.auditEventAfterCommit(
            event = "auth.reauth.issued", actor = member.toAuditActor(),
            target = mapOf("memberId" to memberId), details = mapOf("purpose" to purpose, "expiresAt" to now.plus(PROOF_TTL)),
        )
        return ReauthProofResponse(
            reauthProof = proof,
            expiresIn = PROOF_TTL.seconds,
        )
    }

    fun consume(memberId: Long, purpose: ReauthPurpose, proof: String) {
        if (proof.isBlank()) {
            deny(memberId, purpose, "proof_missing")
        }
        val now = clock.instant()
        val stored = reauthProofRepository.findByProofHashForUpdate(sha256Hex(proof))
            .orElseThrow { denied(memberId, purpose, "proof_not_found") }
        val reason = when {
            stored.memberId != memberId -> "member_mismatch"
            stored.purpose != purpose -> "purpose_mismatch"
            stored.consumedAt != null -> "already_consumed"
            !now.isBefore(stored.expiresAt) -> "expired"
            else -> null
        }
        if (reason != null) deny(memberId, purpose, reason)
        stored.consume(now)
        log.auditEventAfterCommit(
            event = "auth.reauth.consumed", actor = null, target = mapOf("memberId" to memberId),
            details = mapOf("purpose" to purpose),
        )
    }

    private fun randomToken(): String = ByteArray(32).also(secureRandom::nextBytes)
        .let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private fun deny(memberId: Long, purpose: ReauthPurpose, reason: String): Nothing =
        throw denied(memberId, purpose, reason)

    private fun denied(memberId: Long, purpose: ReauthPurpose, reason: String): AuthException {
        log.warn("Reauthentication denied {}", auditContext(mapOf(
            "event" to "auth.reauth.denied", "memberId" to memberId, "purpose" to purpose, "reason" to reason,
        )))
        return AuthException("auth.reauth.proof.invalid")
    }

    companion object {
        private val PROOF_TTL: Duration = Duration.ofMinutes(5)
    }
}
