package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.YearMonth

@Service
@Transactional
class DutyService(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService,
    private val memberService: MemberService,
) {

    @Transactional(readOnly = true)
    fun getDutiesAsMap(member: Member, year: Int, month: Int): Map<Int, DutyDto?> {
        return findDutyByMonthAndYear(member, year, month)
            .associate { it.dutyDate.dayOfMonth to DutyDto(it) }
    }

    fun update(dutyUpdateDto: DutyUpdateDto) {
        val member = memberRepository.findById(dutyUpdateDto.memberId).orElseThrow()

        val duty: Duty? = dutyRepository.findByMemberAndDutyDate(
            member = member,
            dutyDate = YearMonth.of(dutyUpdateDto.year, dutyUpdateDto.month).atDay(dutyUpdateDto.day)
        )

        val dutyType: DutyType? = dutyUpdateDto.dutyTypeId?.let {
            dutyTypeRepository.findById(it).orElseThrow()
        }

        if (duty == null) {
            if (dutyType != null) {
                dutyRepository.save(
                    Duty(
                        member = member,
                        dutyDate = YearMonth.of(dutyUpdateDto.year, dutyUpdateDto.month).atDay(dutyUpdateDto.day),
                        dutyType = dutyType
                    )
                )
            }
            return
        }

        if (dutyType == null) {
            dutyRepository.delete(duty)
            return
        }

        duty.dutyType = dutyType
    }

    fun update(dutyBatchUpdateDto: DutyBatchUpdateDto) {
        val member = memberRepository.findById(dutyBatchUpdateDto.memberId).orElseThrow()
        val dutyType: DutyType? = dutyBatchUpdateDto.dutyTypeId?.let {
            dutyTypeRepository.findById(it).orElseThrow()
        }

        // 1. delete all duties with same year and month
        val old = findDutyByMonthAndYear(member, dutyBatchUpdateDto.year, dutyBatchUpdateDto.month)
        dutyRepository.deleteAll(old)

        if (dutyType == null) {
            return
        }

        // 2. make all duties if dutyTypeId is not null
        val duties = (1..YearMonth.of(dutyBatchUpdateDto.year, dutyBatchUpdateDto.month).lengthOfMonth())
            .map { day ->
                Duty(
                    member = member,
                    dutyDate = YearMonth.of(dutyBatchUpdateDto.year, dutyBatchUpdateDto.month).atDay(day),
                    dutyType = dutyType
                )
            }
        dutyRepository.saveAll(duties)
    }

    fun canEdit(loginMember: LoginMember, memberId: Long): Boolean {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()

        return member.isEquals(loginMember)
                || memberService.canManageTeam(loginMember = loginMember, team = member.team)
                || memberService.isManager(isManager = loginMember, target = member)
    }

    @Transactional(readOnly = true)
    fun getDuties(memberId: Long, yearMonth: YearMonth, loginMember: LoginMember?): List<DutyDto> {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member)

        val team = member.team ?: return emptyList()
        val defaultDutyColor = team.defaultDutyColor
        val calendarView = CalendarView(yearMonth)
        val dutyMap = getDutiesAsMap(member, calendarView.rangeFromDate, calendarView.rangeUntilDate)

        val answer = mutableListOf<DutyDto>()
        for (cur in calendarView.getRangeDate()) {
            val duty = dutyMap.getOrDefault(
                LocalDate.of(cur.year, cur.monthValue, cur.dayOfMonth), DutyDto(
                    year = cur.year,
                    month = cur.monthValue,
                    day = cur.dayOfMonth,
                    dutyColor = defaultDutyColor.name
                )
            )
            answer.add(duty)
        }
        return answer
    }

    private fun getDutiesAsMap(member: Member, from: LocalDate, until: LocalDate): Map<LocalDate, DutyDto> {
        return dutyRepository.findAllByMemberAndDutyDateBetween(
            member, from, until
        )
            .map { d -> DutyDto(d) }
            .associateBy { d ->
                LocalDate.of(
                    d.year, d.month, d.day
                )
            }
    }

    private fun findDutyByMonthAndYear(
        member: Member,
        year: Int,
        month: Int
    ): List<Duty> {
        val from = YearMonth.of(year, month).atDay(1)
        val to = YearMonth.of(year, month).atEndOfMonth()
        return dutyRepository.findAllByMemberAndDutyDateBetween(member, from, to)
    }

}
