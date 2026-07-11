package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyPatternUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyTypeCreateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.team.domain.entity.Team
import com.tistory.shanepark.dutypark.team.repository.TeamRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.duty.repository.MemberDutyPatternRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.RepeatedTest
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

    @RepeatedTest(3)
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

    @RepeatedTest(3)
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
            val executor = Executors.newFixedThreadPool(6)
            val futures = List(6) {
                executor.submit {
                    start.await()
                    dutyService.getDuties(memberId, month.year, month.monthValue, loginMember)
                }
            }
            try {
                start.countDown()
                futures.forEach { it.get(15, TimeUnit.SECONDS) }
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

    @RepeatedTest(3)
    fun `adding a second duty type racing with lookup keeps selected automatic duties consistent`() {
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
            val manualDate = month.atDay(15)
            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val dutyType = dutyTypeRepository.findAll().single { it.team.id == teamId && !it.hidden }
                dutyRepository.saveAndFlush(
                    Duty(
                        member = member,
                        dutyDate = manualDate,
                        dutyType = dutyType,
                        manualOverride = true,
                    )
                )
            }
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
                val duties = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
                assertThat(duties).hasSize(CalendarView.SIZE)
                assertThat(duties.filter { !it.manualOverride && it.dutyType != null })
                    .allMatch { it.dutyDate.dayOfWeek == MONDAY }
                val manualDuty = dutyRepository.findByMemberAndDutyDate(member, manualDate)
                assertThat(manualDuty).isNotNull
                assertThat(requireNotNull(manualDuty).manualOverride).isTrue()
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

    @RepeatedTest(3)
    fun `pattern update racing with month lookup converges to the latest pattern without duplicates`() {
        val memberId = createMemberWithSingleDutyType("패턴변경경쟁")
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
            val loginMember = LoginMember(memberId, name = "패턴변경경쟁")
            runConcurrently(
                {
                    dutyService.getDuties(memberId, month.year, month.monthValue, loginMember)
                },
                {
                    dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(FRIDAY), false))
                },
            )

            // Whichever operation acquired the member lock first, the next lookup must materialize
            // one coherent snapshot of the latest pattern.
            dutyService.getDuties(memberId, month.year, month.monthValue, loginMember)

            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val view = CalendarView(month.year, month.monthValue)
                val duties = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
                assertThat(duties).hasSize(CalendarView.SIZE)
                assertThat(duties.map { it.dutyDate }).doesNotHaveDuplicates()
                assertThat(duties).allMatch { !it.manualOverride }
                assertThat(duties.filter { it.dutyType != null }.map { it.dutyDate.dayOfWeek }.toSet())
                    .containsExactly(FRIDAY)
            }
        } finally {
            deleteMemberAndTeam(memberId)
        }
    }

    @RepeatedTest(3)
    fun `pattern deletion racing with month lookup leaves no future duties`() {
        val memberId = createMemberWithSingleDutyType("패턴삭제경쟁")
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val dutyType = member.team?.dutyTypes?.singleOrNull() ?: error("single duty type required")
                dutyRepository.saveAndFlush(
                    Duty(
                        member = member,
                        dutyDate = month.atDay(12),
                        dutyType = dutyType,
                        manualOverride = true,
                    )
                )
            }
            val loginMember = LoginMember(memberId, name = "패턴삭제경쟁")
            runConcurrently(
                {
                    dutyService.getDuties(memberId, month.year, month.monthValue, loginMember)
                },
                {
                    dutyPatternService.deleteMine(memberId)
                },
            )

            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val view = CalendarView(month.year, month.monthValue)
                assertThat(patternRepository.findFirstByMemberAndEffectiveUntilExclusiveIsNullOrderByIdDesc(member))
                    .isNull()
                assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate))
                    .isEmpty()
            }
        } finally {
            deleteMemberAndTeam(memberId)
        }
    }

    @RepeatedTest(3)
    fun `hiding the sole duty type racing with lookup removes only automatic duties`() {
        val memberId = createMemberWithSingleDutyType("유형숨김경쟁")
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
            val (dutyTypeId, manualDate) = transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val dutyType = dutyTypeRepository.findAll().single { it.team.id == member.team?.id && !it.hidden }
                val date = month.atDay(16)
                dutyRepository.saveAndFlush(Duty(date, dutyType, member, manualOverride = true))
                requireNotNull(dutyType.id) to date
            }
            runConcurrently(
                {
                    dutyService.getDuties(
                        memberId,
                        month.year,
                        month.monthValue,
                        LoginMember(memberId, name = "유형숨김경쟁"),
                    )
                },
                {
                    dutyTypeService.updateVisibility(dutyTypeId, true)
                },
            )

            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val view = CalendarView(month.year, month.monthValue)
                val duties = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
                assertThat(duties.filter { !it.manualOverride && it.dutyType != null }).isEmpty()
                assertThat(duties.single { it.dutyDate == manualDate }.manualOverride).isTrue()
            }
        } finally {
            deleteMemberAndTeam(memberId)
        }
    }

    @RepeatedTest(3)
    fun `restoring the sole duty type racing with lookup resumes materialization without duplicates`() {
        val memberId = createMemberWithSingleDutyType("유형복원경쟁")
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            dutyPatternService.updateMine(memberId, DutyPatternUpdateDto(setOf(MONDAY), false))
            val dutyTypeId = transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                requireNotNull(member.team?.dutyTypes?.single()?.id)
            }
            dutyTypeService.updateVisibility(dutyTypeId, true)
            runConcurrently(
                {
                    dutyService.getDuties(
                        memberId,
                        month.year,
                        month.monthValue,
                        LoginMember(memberId, name = "유형복원경쟁"),
                    )
                },
                {
                    dutyTypeService.updateVisibility(dutyTypeId, false)
                },
            )

            dutyService.getDuties(
                memberId,
                month.year,
                month.monthValue,
                LoginMember(memberId, name = "유형복원경쟁"),
            )
            transactionTemplate.execute {
                val member = memberRepository.findById(memberId).orElseThrow()
                val view = CalendarView(month.year, month.monthValue)
                val duties = dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate)
                assertThat(duties).hasSize(CalendarView.SIZE)
                assertThat(duties.map { it.dutyDate }).doesNotHaveDuplicates()
                assertThat(duties).allMatch { !it.manualOverride }
            }
        } finally {
            deleteMemberAndTeam(memberId)
        }
    }

    @RepeatedTest(3)
    fun `parallel month lookups for different members in one team all complete consistently`() {
        val memberIds = transactionTemplate.execute {
            val team = teamRepository.save(Team("p-${System.nanoTime().toString().takeLast(12)}"))
            dutyTypeRepository.saveAndFlush(team.addDutyType("근무", "#123456"))
            (1..4).map { index ->
                val member = Member("병렬회원$index")
                team.addMember(member)
                requireNotNull(memberRepository.saveAndFlush(member).id)
            }
        }
        val month = YearMonth.now(ZoneId.of("Asia/Seoul")).plusMonths(1)
        try {
            memberIds.forEach {
                dutyPatternService.updateMine(it, DutyPatternUpdateDto(setOf(MONDAY), false))
            }
            val start = CountDownLatch(1)
            val executor = Executors.newFixedThreadPool(memberIds.size)
            val futures = memberIds.map { memberId ->
                executor.submit {
                    start.await()
                    dutyService.getDuties(
                        memberId,
                        month.year,
                        month.monthValue,
                        LoginMember(memberId, name = "병렬회원"),
                    )
                }
            }
            try {
                start.countDown()
                futures.forEach { it.get(20, TimeUnit.SECONDS) }
            } finally {
                futures.filterNot { it.isDone }.forEach { it.cancel(true) }
                executor.shutdownNow()
                executor.awaitTermination(5, TimeUnit.SECONDS)
            }

            transactionTemplate.execute {
                val view = CalendarView(month.year, month.monthValue)
                memberIds.forEach { memberId ->
                    val member = memberRepository.findById(memberId).orElseThrow()
                    assertThat(dutyRepository.findAllByMemberAndDutyDateBetween(member, view.startDate, view.endDate))
                        .hasSize(CalendarView.SIZE)
                }
            }
        } finally {
            memberIds.forEach(::deleteMemberAndTeam)
        }
    }

    private fun createMemberWithSingleDutyType(name: String): Long = transactionTemplate.execute {
        val team = teamRepository.save(Team("x-${System.nanoTime().toString().takeLast(12)}"))
        dutyTypeRepository.saveAndFlush(team.addDutyType("근무", "#123456"))
        val member = Member(name)
        team.addMember(member)
        requireNotNull(memberRepository.saveAndFlush(member).id)
    }

    private fun deleteMemberAndTeam(memberId: Long) {
        transactionTemplate.execute {
            val member = memberRepository.findById(memberId).orElse(null) ?: return@execute
            val team = member.team
            if (team != null) dutyRepository.deleteAllByTeamId(requireNotNull(team.id))
            patternRepository.deleteAll(patternRepository.findAllByMemberOrderByEffectiveFromDescIdDesc(member))
            patternRepository.flush()
            team?.removeMember(member)
            memberRepository.delete(member)
            if (team != null && team.members.isEmpty()) teamRepository.delete(team)
        }
    }

    private fun runConcurrently(vararg operations: () -> Unit) {
        val start = CountDownLatch(1)
        val executor = Executors.newFixedThreadPool(operations.size)
        val futures = operations.map { operation ->
            executor.submit {
                start.await()
                operation()
            }
        }
        try {
            start.countDown()
            futures.forEach { it.get(15, TimeUnit.SECONDS) }
        } finally {
            futures.filterNot { it.isDone }.forEach { it.cancel(true) }
            executor.shutdownNow()
            executor.awaitTermination(5, TimeUnit.SECONDS)
        }
    }
}
