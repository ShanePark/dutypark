package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.support.TransactionTemplate
import java.time.DayOfWeek.FRIDAY
import java.time.DayOfWeek.MONDAY
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit

@SpringBootTest
class DutyPatternConcurrencyIntegrationTest {
    @Autowired lateinit var dutyPatternService: DutyPatternService
    @Autowired lateinit var patternRepository: MemberDutyPatternRepository
    @Autowired lateinit var memberRepository: MemberRepository
    @Autowired lateinit var teamRepository: TeamRepository
    @Autowired lateinit var dutyTypeRepository: DutyTypeRepository
    @Autowired lateinit var transactionTemplate: TransactionTemplate

    @Test
    fun `concurrent pattern updates leave exactly one active version`() {
        val memberId = transactionTemplate.execute {
            val team = teamRepository.save(Team("c-${System.nanoTime().toString().takeLast(12)}"))
            dutyTypeRepository.saveAndFlush(team.addDutyType("근무", "#123456"))
            val member = Member("동시성")
            team.addMember(member)
            requireNotNull(memberRepository.saveAndFlush(member).id)
        }
        try {
            val start = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            val futures = listOf(
                executor.submit {
                    start.await()
                    dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
                },
                executor.submit {
                    start.await()
                    dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(FRIDAY), false))
                },
            )
            try {
                start.countDown()
                futures.forEach { it.get(10, TimeUnit.SECONDS) }
            } finally {
                futures.filterNot { it.isDone }.forEach { it.cancel(true) }
                executor.shutdownNow()
                executor.awaitTermination(5, TimeUnit.SECONDS)
            }

            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val patterns = patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member)
                assertThat(patterns.count { it.effectiveUntilExclusive == null }).isEqualTo(1)
                assertThat(patterns).hasSize(2)
            }
        } finally {
            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElse(null) ?: return@execute
                val team = member.team
                patternRepository.deleteAll(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member))
                patternRepository.flush()
                team?.removeMember(member)
                memberRepository.delete(member)
                if (team != null) teamRepository.delete(team)
            }
        }
    }
}
