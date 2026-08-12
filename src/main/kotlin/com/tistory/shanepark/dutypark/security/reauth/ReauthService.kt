package com.tistory.shanepark.dutypark.security.reauth

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
        return ReauthProofResponse(
            reauthProof = proof,
            expiresIn = PROOF_TTL.seconds,
        )
    }

    fun consume(memberId: Long, purpose: ReauthPurpose, proof: String) {
        if (proof.isBlank()) {
            throw invalidProof()
        }
        val now = clock.instant()
        val stored = reauthProofRepository.findByProofHashForUpdate(sha256Hex(proof))
            .orElseThrow(::invalidProof)
        if (
            stored.memberId != memberId || stored.purpose != purpose || stored.consumedAt != null ||
            !now.isBefore(stored.expiresAt)
        ) {
            throw invalidProof()
        }
        stored.consume(now)
    }

    private fun randomToken(): String = ByteArray(32).also(secureRandom::nextBytes)
        .let { Base64.getUrlEncoder().withoutPadding().encodeToString(it) }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }

    private fun invalidProof() = AuthException("auth.reauth.proof.invalid")

    companion object {
        private val PROOF_TTL: Duration = Duration.ofMinutes(5)
    }
}
