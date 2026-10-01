package com.tistory.shanepark.dutypark.security.reauth

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.any
import org.mockito.kotlin.mock
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.mockito.junit.jupiter.MockitoExtension
import java.nio.charset.StandardCharsets
import java.security.MessageDigest
import java.time.Clock
import java.time.Instant
import java.time.ZoneOffset
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class ReauthServiceTest {

    private val proofRepository: ReauthProofRepository = mock()
    private val memberRepository: MemberRepository = mock()
    private val now = Instant.parse("2026-08-12T03:00:00Z")
    private val clock = Clock.fixed(now, ZoneOffset.UTC)
    private lateinit var service: ReauthService

    @BeforeEach
    fun setUp() {
        service = ReauthService(proofRepository, memberRepository, clock)
    }

    @Test
    fun `issue creates a five minute single-purpose proof for active member`() {
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(memberWithId(1L)))
        whenever(proofRepository.save(any<ReauthProof>()))
            .thenAnswer { it.arguments[0] as ReauthProof }

        val response = service.issue(1L, ReauthPurpose.DELETE_ACCOUNT)

        assertThat(response.reauthProof).isNotBlank()
        assertThat(response.expiresIn).isEqualTo(300)
        val captor = argumentCaptor<ReauthProof>()
        verify(proofRepository).save(captor.capture())
        assertThat(captor.firstValue.memberId).isEqualTo(1L)
        assertThat(captor.firstValue.purpose).isEqualTo(ReauthPurpose.DELETE_ACCOUNT)
        assertThat(captor.firstValue.createdAt).isEqualTo(now)
        assertThat(captor.firstValue.expiresAt).isEqualTo(now.plusSeconds(300))
        assertThat(captor.firstValue.proofHash).isEqualTo(sha256Hex(response.reauthProof))
    }

    @Test
    fun `consume accepts matching proof and marks it consumed`() {
        val stored = proof(memberId = 1L)
        whenever(proofRepository.findByProofHashForUpdate(sha256Hex("proof"))).thenReturn(Optional.of(stored))

        service.consume(1L, ReauthPurpose.DELETE_ACCOUNT, "proof")

        assertThat(stored.consumedAt).isEqualTo(now)
    }

    @Test
    fun `consume rejects proof issued for another member`() {
        val stored = proof(memberId = 2L)
        whenever(proofRepository.findByProofHashForUpdate(sha256Hex("proof"))).thenReturn(Optional.of(stored))

        assertInvalidProof { service.consume(1L, ReauthPurpose.DELETE_ACCOUNT, "proof") }
        assertThat(stored.consumedAt).isNull()
    }

    @Test
    fun `consume rejects reused proof`() {
        val stored = proof(memberId = 1L).also { it.consume(now.minusSeconds(1)) }
        whenever(proofRepository.findByProofHashForUpdate(sha256Hex("proof"))).thenReturn(Optional.of(stored))

        assertInvalidProof { service.consume(1L, ReauthPurpose.DELETE_ACCOUNT, "proof") }
    }

    @Test
    fun `consume rejects proof at expiry boundary`() {
        val stored = proof(memberId = 1L, expiresAt = now)
        whenever(proofRepository.findByProofHashForUpdate(sha256Hex("proof"))).thenReturn(Optional.of(stored))

        assertInvalidProof { service.consume(1L, ReauthPurpose.DELETE_ACCOUNT, "proof") }
    }

    @Test
    fun `proof lifecycle logs purpose and member without proof or hash`() {
        whenever(memberRepository.findById(1L)).thenReturn(Optional.of(memberWithId(1L)))
        whenever(proofRepository.save(any<ReauthProof>())).thenAnswer { it.arguments[0] as ReauthProof }
        val logger = org.slf4j.LoggerFactory.getLogger(ReauthService::class.java) as ch.qos.logback.classic.Logger
        val appender = ch.qos.logback.core.read.ListAppender<ch.qos.logback.classic.spi.ILoggingEvent>().apply { start() }
        logger.addAppender(appender)
        try {
            val issued = service.issue(1L, ReauthPurpose.DELETE_ACCOUNT)
            val stored = ReauthProof(ReauthPurpose.DELETE_ACCOUNT, sha256Hex(issued.reauthProof), 1L, now.plusSeconds(300), now)
            whenever(proofRepository.findByProofHashForUpdate(sha256Hex(issued.reauthProof))).thenReturn(Optional.of(stored))
            service.consume(1L, ReauthPurpose.DELETE_ACCOUNT, issued.reauthProof)
            assertInvalidProof { service.consume(1L, ReauthPurpose.DELETE_ACCOUNT, issued.reauthProof) }
            val logs = appender.list.joinToString("\n") { it.formattedMessage }
            assertThat(logs).contains("auth.reauth.issued", "auth.reauth.consumed", "auth.reauth.denied", "already_consumed", "DELETE_ACCOUNT")
                .doesNotContain(issued.reauthProof, sha256Hex(issued.reauthProof), "member@duty.park", "password")
        } finally {
            logger.detachAppender(appender)
            appender.stop()
        }
    }

    private fun proof(
        memberId: Long,
        purpose: ReauthPurpose = ReauthPurpose.DELETE_ACCOUNT,
        expiresAt: Instant = now.plusSeconds(1),
    ) = ReauthProof(
        purpose = purpose,
        proofHash = sha256Hex("proof"),
        memberId = memberId,
        expiresAt = expiresAt,
        createdAt = now.minusSeconds(1),
    )

    private fun memberWithId(id: Long): Member = Member("member", "member@duty.park", "password").also {
        val field = Member::class.java.getDeclaredField("id")
        field.isAccessible = true
        field.set(it, id)
    }

    private fun assertInvalidProof(block: () -> Unit) {
        val exception = assertThrows<AuthException>(block)
        assertThat(exception.message).isEqualTo("auth.reauth.proof.invalid")
    }

    private fun sha256Hex(value: String): String = MessageDigest.getInstance("SHA-256")
        .digest(value.toByteArray(StandardCharsets.UTF_8))
        .joinToString("") { "%02x".format(it) }
}
