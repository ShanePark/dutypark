package com.tistory.shanepark.dutypark.member.accountdeletion

import com.tistory.shanepark.dutypark.member.accountdeletion.domain.AccountDeletionJob
import com.tistory.shanepark.dutypark.member.accountdeletion.dto.AccountDeletionRequest
import com.tistory.shanepark.dutypark.member.accountdeletion.exception.AccountDeletionException
import com.tistory.shanepark.dutypark.member.accountdeletion.repository.AccountDeletionJobRepository
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionReceiptToken
import com.tistory.shanepark.dutypark.member.accountdeletion.service.AccountDeletionService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.MemberSocialAccountRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.security.reauth.ReauthService
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.kotlin.mock
import org.mockito.kotlin.never
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import org.springframework.security.crypto.password.PasswordEncoder
import org.springframework.test.util.ReflectionTestUtils
import org.springframework.jdbc.core.namedparam.NamedParameterJdbcTemplate
import java.time.Clock
import java.time.Duration
import java.time.Instant
import java.time.ZoneOffset
import java.util.Optional

@ExtendWith(org.mockito.junit.jupiter.MockitoExtension::class)
class AccountDeletionReceiptConcurrencyTest {

    private val memberRepository: MemberRepository = mock()
    private val memberManagerRepository: MemberManagerRepository = mock()
    private val memberSocialAccountRepository: MemberSocialAccountRepository = mock()
    private val refreshTokenRepository: RefreshTokenRepository = mock()
    private val teamRepository: TeamRepository = mock()
    private val jobRepository: AccountDeletionJobRepository = mock()
    private val reauthService: ReauthService = mock()
    private val passwordEncoder: PasswordEncoder = mock()
    private val jdbc: NamedParameterJdbcTemplate = mock()
    private val clock: Clock = Clock.fixed(NOW, ZoneOffset.UTC)

    private lateinit var service: AccountDeletionService

    @BeforeEach
    fun setUp() {
        service = AccountDeletionService(
            memberRepository = memberRepository,
            memberManagerRepository = memberManagerRepository,
            memberSocialAccountRepository = memberSocialAccountRepository,
            refreshTokenRepository = refreshTokenRepository,
            teamRepository = teamRepository,
            jobRepository = jobRepository,
            reauthService = reauthService,
            passwordEncoder = passwordEncoder,
            jdbc = jdbc,
            clock = clock,
        )
    }

    @Test
    fun `late discovered pending job reconciles the caller receipt`() {
        val root = pendingMember()
        val token = AccountDeletionReceiptToken.generate()
        val job = pendingJob()
        job.issueReceipt(
            receiptTokenHash = AccountDeletionReceiptToken.hash(token),
            estimatedCompletionAt = NOW.plusSeconds(300),
        )
        whenever(jobRepository.findByRootMemberIdForUpdate(root.id!!))
            .thenReturn(Optional.empty(), Optional.of(job))
        whenever(memberRepository.findMemberWithTeamForUpdate(root.id!!)).thenReturn(Optional.of(root))

        val accepted = service.requestDeletion(
            login = LoginMember(id = root.id!!, name = root.name),
            request = AccountDeletionRequest(confirmation = "DELETE", receiptToken = token),
        )

        assertThat(accepted.receiptToken).isEqualTo(token)
        assertThat(accepted.jobId).isEqualTo(job.id)
        verify(jobRepository, never()).findByRootMemberId(root.id!!)
    }

    @Test
    fun `late discovered legacy job issues the caller receipt`() {
        val root = pendingMember()
        val token = AccountDeletionReceiptToken.generate()
        val job = pendingJob()
        whenever(jobRepository.findByRootMemberIdForUpdate(root.id!!))
            .thenReturn(Optional.empty(), Optional.of(job))
        whenever(memberRepository.findMemberWithTeamForUpdate(root.id!!)).thenReturn(Optional.of(root))

        val accepted = service.requestDeletion(
            login = LoginMember(id = root.id!!, name = root.name),
            request = AccountDeletionRequest(confirmation = "DELETE", receiptToken = token),
        )

        assertThat(accepted.receiptToken).isEqualTo(token)
        assertThat(job.receiptTokenHash).isEqualTo(AccountDeletionReceiptToken.hash(token))
    }

    @Test
    fun `expired status cleanup does not mutate a receipt when the expected hash was replaced`() {
        val oldToken = AccountDeletionReceiptToken.generate()
        val oldHash = AccountDeletionReceiptToken.hash(oldToken)
        val job = pendingJob()
        val terminalAt = NOW.minus(Duration.ofDays(31))
        job.issueReceipt(oldHash, NOW.plusSeconds(300))
        job.claim(terminalAt.minusSeconds(1))
        job.markCompleted(terminalAt)
        whenever(jobRepository.findByReceiptTokenHash(oldHash)).thenReturn(Optional.of(job))
        whenever(jobRepository.clearExpiredReceiptTokenHash(oldHash, NOW)).thenReturn(0)

        assertThatThrownBy { service.findStatus(oldToken) }
            .isInstanceOf(AccountDeletionException::class.java)
            .extracting("message")
            .isEqualTo("accountDeletion.receipt.notFound")
        assertThat(job.receiptTokenHash).isEqualTo(oldHash)
        verify(jobRepository).clearExpiredReceiptTokenHash(oldHash, NOW)
    }

    private fun pendingMember(): Member = Member(
        name = "pending",
        email = "pending@example.com",
        password = "encoded",
    ).also {
        ReflectionTestUtils.setField(it, "id", MEMBER_ID)
        it.markDeletionPending(NOW.minusSeconds(1))
    }

    private fun pendingJob(): AccountDeletionJob = AccountDeletionJob(
        rootMemberId = MEMBER_ID,
        nextAttemptAt = NOW,
        createdAt = NOW.minusSeconds(60),
    ).also {
        ReflectionTestUtils.setField(it, "id", JOB_ID)
    }

    companion object {
        private const val MEMBER_ID = 101L
        private const val JOB_ID = 202L
        private val NOW = Instant.parse("2026-08-29T07:00:00Z")
    }
}
