package com.tistory.shanepark.dutypark.consent.service

import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEvent
import com.tistory.shanepark.dutypark.consent.domain.AiScheduleParsingConsentEventType
import com.tistory.shanepark.dutypark.consent.repository.AiScheduleParsingConsentEventRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.policy.domain.entity.PolicyVersion
import com.tistory.shanepark.dutypark.policy.domain.enums.PolicyType
import com.tistory.shanepark.dutypark.policy.service.PolicyService
import org.assertj.core.api.Assertions.assertThat
import org.assertj.core.api.Assertions.assertThatThrownBy
import org.junit.jupiter.api.BeforeEach
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.extension.ExtendWith
import org.mockito.Mock
import org.mockito.junit.jupiter.MockitoExtension
import org.mockito.kotlin.any
import org.mockito.kotlin.argumentCaptor
import org.mockito.kotlin.never
import org.mockito.kotlin.reset
import org.mockito.kotlin.verify
import org.mockito.kotlin.whenever
import java.time.LocalDate
import java.time.LocalDateTime
import java.util.Optional

@ExtendWith(MockitoExtension::class)
class AiScheduleParsingConsentServiceTest {
    @Mock
    lateinit var consentEventRepository: AiScheduleParsingConsentEventRepository

    @Mock
    lateinit var memberRepository: MemberRepository

    @Mock
    lateinit var policyService: PolicyService

    lateinit var consentService: AiScheduleParsingConsentService

    private val member = Member(name = "member", email = "member@example.com", password = "password")
    private val currentPolicy = PolicyVersion(
        policyType = PolicyType.AI_SCHEDULE_PARSING,
        version = "2026-08-13",
        content = "AI policy",
        effectiveDate = LocalDate.of(2026, 8, 13),
    )

    @BeforeEach
    fun setUp() {
        consentService = AiScheduleParsingConsentService(consentEventRepository, memberRepository, policyService)
        whenever(policyService.getCurrentPolicy(PolicyType.AI_SCHEDULE_PARSING)).thenReturn(currentPolicy)
    }

    @Test
    fun `getConsent returns unconsented state when no event exists`() {
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(null)

        val result = consentService.getConsent(1L)

        assertThat(result.currentPolicyVersion).isEqualTo("2026-08-13")
        assertThat(result.policy.version).isEqualTo("2026-08-13")
        assertThat(result.consented).isFalse()
        assertThat(result.previouslyConsentedToCurrentPolicy).isFalse()
        assertThat(result.consentVersion).isNull()
        assertThat(result.needsRenewal).isFalse()
        assertThat(result.consentedAt).isNull()
        assertThat(result.revokedAt).isNull()
    }

    @Test
    fun `grant rejects a version other than the current policy`() {
        assertThatThrownBy {
            consentService.updateConsent(1L, true, "old", null, null)
        }
            .isInstanceOf(BadRequestException::class.java)
            .hasMessage("consent.aiScheduleParsing.policyVersionMismatch")

        verify(memberRepository, never()).findMemberWithTeamForUpdate(any())
        verify(consentEventRepository, never()).save(any())
    }

    @Test
    fun `grant records current version and request metadata`() {
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(null)
        whenever(consentEventRepository.save(any())).thenAnswer { it.arguments[0] }

        val result = consentService.updateConsent(
            memberId = 1L,
            consented = true,
            policyVersion = "2026-08-13",
            ipAddress = "1.2.3.4",
            userAgent = "a".repeat(600),
        )

        argumentCaptor<AiScheduleParsingConsentEvent>().apply {
            verify(consentEventRepository).save(capture())
            assertThat(firstValue.eventType).isEqualTo(AiScheduleParsingConsentEventType.GRANTED)
            assertThat(firstValue.policyVersion).isEqualTo("2026-08-13")
            assertThat(firstValue.ipAddress).isEqualTo("1.2.3.4")
            assertThat(firstValue.userAgent).hasSize(500)
        }
        assertThat(result.consented).isTrue()
        assertThat(result.previouslyConsentedToCurrentPolicy).isTrue()
        assertThat(result.needsRenewal).isFalse()
        assertThat(result.consentedAt).isNotNull()
    }

    @Test
    fun `repeating current grant is idempotent`() {
        val grant = event(AiScheduleParsingConsentEventType.GRANTED, "2026-08-13")
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(grant)

        val result = consentService.updateConsent(1L, true, "2026-08-13", null, null)

        assertThat(result.consented).isTrue()
        verify(consentEventRepository, never()).save(any())
    }

    @Test
    fun `first refusal records a revoked event`() {
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(null)
        whenever(consentEventRepository.save(any())).thenAnswer { it.arguments[0] }

        val result = consentService.updateConsent(1L, false, null, null, null)

        argumentCaptor<AiScheduleParsingConsentEvent>().apply {
            verify(consentEventRepository).save(capture())
            assertThat(firstValue.eventType).isEqualTo(AiScheduleParsingConsentEventType.REVOKED)
            assertThat(firstValue.policyVersion).isNull()
        }
        assertThat(result.consented).isFalse()
        assertThat(result.revokedAt).isNotNull()
    }

    @Test
    fun `revoke records an event without policy version and repeating revoke is idempotent`() {
        val grant = event(AiScheduleParsingConsentEventType.GRANTED, "2026-08-13")
        whenever(memberRepository.findMemberWithTeamForUpdate(1L)).thenReturn(Optional.of(member))
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(grant)
        whenever(consentEventRepository.save(any())).thenAnswer { it.arguments[0] }

        val revoked = consentService.updateConsent(1L, false, "ignored", null, null)

        val eventCaptor = argumentCaptor<AiScheduleParsingConsentEvent>()
        verify(consentEventRepository).save(eventCaptor.capture())
        assertThat(eventCaptor.firstValue.eventType).isEqualTo(AiScheduleParsingConsentEventType.REVOKED)
        assertThat(eventCaptor.firstValue.policyVersion).isNull()
        assertThat(revoked.consented).isFalse()
        assertThat(revoked.revokedAt).isNotNull()

        reset(consentEventRepository)
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L))
            .thenReturn(eventCaptor.firstValue)
        val repeated = consentService.updateConsent(1L, false, null, null, null)

        assertThat(repeated.consented).isFalse()
        verify(consentEventRepository, never()).save(any())
    }

    @Test
    fun `stale grant remains consented but needs renewal and is not current consent`() {
        val consentedAt = LocalDateTime.of(2026, 1, 1, 12, 0)
        val oldGrant = event(AiScheduleParsingConsentEventType.GRANTED, "2026-01-01", consentedAt)
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(oldGrant)

        val result = consentService.getConsent(1L)

        assertThat(result.consented).isTrue()
        assertThat(result.consentVersion).isEqualTo("2026-01-01")
        assertThat(result.needsRenewal).isTrue()
        assertThat(result.consentedAt).isEqualTo(consentedAt)
        assertThat(consentService.hasCurrentConsent(1L)).isFalse()
    }

    @Test
    fun `current grant is current consent while revoked event is not`() {
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L))
            .thenReturn(event(AiScheduleParsingConsentEventType.GRANTED, "2026-08-13"))
        assertThat(consentService.hasCurrentConsent(1L)).isTrue()

        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L))
            .thenReturn(event(AiScheduleParsingConsentEventType.REVOKED, null))
        assertThat(consentService.hasCurrentConsent(1L)).isFalse()
    }

    @Test
    fun `revoked member remains previously consented to the current policy`() {
        val revoked = event(AiScheduleParsingConsentEventType.REVOKED, null)
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(revoked)
        whenever(
            consentEventRepository.existsByMember_IdAndEventTypeAndPolicyVersion(
                1L,
                AiScheduleParsingConsentEventType.GRANTED,
                "2026-08-13",
            )
        ).thenReturn(true)

        val result = consentService.getConsent(1L)

        assertThat(result.consented).isFalse()
        assertThat(result.previouslyConsentedToCurrentPolicy).isTrue()
        assertThat(consentService.hasCurrentConsent(1L)).isFalse()
    }

    @Test
    fun `grant to an older policy is not previous consent to the current policy`() {
        val oldGrant = event(AiScheduleParsingConsentEventType.GRANTED, "2026-01-01")
        whenever(consentEventRepository.findTopByMember_IdOrderByCreatedAtDescIdDesc(1L)).thenReturn(oldGrant)

        val result = consentService.getConsent(1L)

        assertThat(result.previouslyConsentedToCurrentPolicy).isFalse()
    }

    @Test
    fun `policy unavailable uses machine readable not found code`() {
        whenever(policyService.getCurrentPolicy(PolicyType.AI_SCHEDULE_PARSING)).thenReturn(null)

        assertThatThrownBy { consentService.getConsent(1L) }
            .isInstanceOf(NoSuchElementException::class.java)
            .hasMessage("consent.aiScheduleParsing.policyUnavailable")
        assertThat(consentService.hasCurrentConsent(1L)).isFalse()
    }

    private fun event(
        type: AiScheduleParsingConsentEventType,
        version: String?,
        createdAt: LocalDateTime = LocalDateTime.now(),
    ) = AiScheduleParsingConsentEvent(
        member = member,
        eventType = type,
        policyVersion = version,
        createdAt = createdAt,
    )
}
