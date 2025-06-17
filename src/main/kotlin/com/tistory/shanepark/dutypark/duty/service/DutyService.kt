package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.OtherDutyResponse
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.holiday.domain.HolidayDto
import com.tistory.shanepark.dutypark.holiday.service.HolidayService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import com.tistory.shanepark.dutypark.team.domain.enums.WorkType
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.LocalDate.of
import java.time.YearMonth

@Service
@Transactional
class DutyService(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService,
    private val memberService: MemberService,
    private val holidayService: HolidayService,
) {
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

    @Transactional(readOnly = false)
    fun getDutiesAndInitLazyIfNeeded(memberId: Long, year: Int, month: Int, loginMember: LoginMember?): List<DutyDto> {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member)

        val team = member.team ?: return emptyList()
        val defaultDutyColor = team.defaultDutyColor
        val calendarView = CalendarView(year = year, month = month)
        var duties = dutyRepository.findAllByMemberAndDutyDateBetween(
            member = member,
            calendarView.startDate,
            calendarView.endDate
        )
        if (shouldLazyInitDuty(member, duties)) {
            duties = lazyInitDuty(member = member, calendarView = calendarView, duties = duties)
        }

        val dutyMap = duties.map { d -> DutyDto(d) }
            .associateBy { d ->
                of(d.year, d.month, d.day)
            }

        val answer = mutableListOf<DutyDto>()
        for (cur in calendarView.dates) {
            val duty = dutyMap.getOrDefault(
                of(cur.year, cur.monthValue, cur.dayOfMonth), DutyDto(
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

    private fun shouldLazyInitDuty(
        member: Member,
        duties: List<Duty>,
    ): Boolean {
        val team = member.team ?: return false
        val workType = team.workType
        if (workType != WorkType.WEEKDAY) {
            return false
        }
        val dutyTypes = team.dutyTypes
        if (dutyTypes.isEmpty() || dutyTypes.size > 1) {
            return false
        }
        val startWeekAndEndWeekAllWork = 10
        return duties.size <= startWeekAndEndWeekAllWork
    }

    private fun lazyInitDuty(
        member: Member,
        calendarView: CalendarView,
        duties: List<Duty>
    ): List<Duty> {
        val team = member.team ?: throw IllegalArgumentException("Member ${member.id} does not belong to any team")
        val dutyTypes = team.dutyTypes
        if (dutyTypes.isEmpty() || dutyTypes.size > 1) {
            throw IllegalArgumentException("Team ${team.id} must have exactly one duty type for lazy initialization")
        }
        val dutyType = dutyTypes.first()
        return when (team.workType) {
            WorkType.WEEKDAY -> initWeekDayDuties(member, dutyType, calendarView, duties)
            WorkType.FLEXIBLE -> throw IllegalArgumentException("Cannot lazy init flexible duties")
            else -> {
                duties
            }
        }
    }

    private fun initWeekDayDuties(
        member: Member,
        dutyType: DutyType,
        calendarView: CalendarView,
        dutiesBefore: List<Duty>
    ): List<Duty> {
        val duties = mutableListOf<Duty>()
        var current = calendarView.startDate
        val holidays = holidayService.findHolidays(calendarView)
        val dutiesBeforeMap = dutiesBefore.associateBy { it.dutyDate }
        while (current <= calendarView.endDate) {
            if (isWeekDaysAndNotHoliday(current = current, calendarView = calendarView, holidays = holidays)) {
                val existing = dutiesBeforeMap[current]
                val duty = existing ?: Duty(member = member, dutyDate = current, dutyType = dutyType)
                duties.add(duty)
            }
            current = current.plusDays(1)
        }
        return dutyRepository.saveAll(duties)
    }

    private fun isWeekDaysAndNotHoliday(
        current: LocalDate,
        calendarView: CalendarView,
        holidays: Array<List<HolidayDto>>
    ): Boolean {
        if (current.dayOfWeek.value > 5) return false
        val index = calendarView.getIndex(current)
        holidays[index].forEach {
            if (it.isHoliday) return false
        }
        return true
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

    fun getOtherDuties(
        loginMember: LoginMember,
        memberIds: List<Long>,
        year: Int, month: Int
    ): List<OtherDutyResponse> {
        return memberIds.map { id ->
            val member = memberRepository.findById(id).orElseThrow()
            val team = member.team ?: throw IllegalArgumentException("Member with id $id does not belong to any team")
            val duties =
                getDutiesAndInitLazyIfNeeded(memberId = id, year = year, month = month, loginMember = loginMember).map {
                    if (it.dutyType.isNullOrBlank()) {
                        it.copy(dutyType = team.defaultDutyName, dutyColor = team.defaultDutyColor.name)
                    } else it
                }
            OtherDutyResponse(name = member.name, duties = duties)
        }.toList()
    }

}
