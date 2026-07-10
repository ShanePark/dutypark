package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.boot.test.context.SpringBootTest
import org.springframework.transaction.support.TransactionTemplate
import java.time.DayOfWeek.FRIDAY
import java.time.DayOfWeek.MONDAY
import java.time.YearMonth
import java.time.ZoneId
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
    @Autowired lateinit var dutyRepository: DutyRepository
    @Autowired lateinit var dutyService: DutyService
    @Autowired lateinit var dutyTypeService: DutyTypeService
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
                assertThat(patterns).hasSize(1)
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

    @Test
    fun `concurrent month lookups materialize each date exactly once`() {
        val memberId = transactionTemplate.execute {
            val team = teamRepository.save(Team("m-${System.nanoTime().toString().takeLast(12)}"))
            dutyTypeRepository.saveAndFlush(team.addDutyType("근무", "#123456"))
            val member = Member("동시조회")
            team.addMember(member)
            requireNotNull(memberRepository.saveAndFlush(member).id)
        }
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
            val loginMember = LoginMember(memberId, name = "동시조회")
            val start = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            val futures = List(2) {
                executor.submit {
                    start.await()
                    dutyService.getDuties(memberId, month.year, month.monthValue, loginMember)
                }
            }
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
                val view = CalendarView(month.year, month.monthValue)
                assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate))
                    .hasSize(CalendarView.SIZE)
            }
        } finally {
            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElse(null) ?: return@execute
                val team = member.team
                if (team != null) dutyRepository.deleteAllByTeamId(requireNotNull(team.id))
                patternRepository.deleteAll(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member))
                patternRepository.flush()
                team?.removeMember(member)
                memberRepository.delete(member)
                if (team != null) teamRepository.delete(team)
            }
        }
    }

    @Test
    fun `adding a second duty type cannot leave stale automatic duties from a concurrent lookup`() {
        val teamIdAndMemberId = transactionTemplate.execute {
            val team = teamRepository.save(Team("t-${System.nanoTime().toString().takeLast(12)}"))
            dutyTypeRepository.saveAndFlush(team.addDutyType("근무", "#123456"))
            val member = Member("유형동시성")
            team.addMember(member)
            requireNotNull(team.id) to requireNotNull(memberRepository.saveAndFlush(member).id)
        }
        val (teamId, memberId) = teamIdAndMemberId
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
            val start = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(2)
            val futures = listOf(
                executor.submit {
                    start.await()
                    dutyService.getDuties(memberId, month.year, month.monthValue, LoginMember(memberId, name = "유형동시성"))
                },
                executor.submit {
                    start.await()
                    dutyTypeService.addDutyType(DutyTypeCreateDto(teamId, "추가", "#abcdef"))
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
                val view = CalendarView(month.year, month.monthValue)
                assertThat(
                    dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
                        .filter { !it.manualOverride }
                ).isEmpty()
            }
        } finally {
            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElse(null) ?: return@execute
                val team = member.team
                dutyRepository.deleteAllByTeamId(teamId)
                patternRepository.deleteAll(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member))
                patternRepository.flush()
                team?.removeMember(member)
                memberRepository.delete(member)
                if (team != null) teamRepository.delete(team)
            }
        }
    }
}
