package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyBatchUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.enums.Color
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.YearMonth

@Service
@Transactional
class DutyService(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService
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
                save(
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

    fun save(duty: Duty): Duty {
        return dutyRepository.save(duty)
    }

    fun canEdit(
        loginMember: LoginMember, memberId: Long
    ): Boolean {
        val member = memberRepository.findMemberWithDepartment(memberId).orElseThrow()
        if (member.id == loginMember.id) {
            return true
        }
        if (member.department?.manager?.id == loginMember.id) {
            return true
        }
        return false
    }

    @Transactional(readOnly = true)
    fun getDuties(memberId: Long, yearMonth: YearMonth, loginMember: LoginMember?): List<DutyDto> {
        val member = memberRepository.findMemberWithDepartment(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member)
        val department = member.department ?: return emptyList()
        val defaultDutyColor = department.defaultDutyColor

        val answer = mutableListOf<DutyDto>()
        val calendarView = CalendarView(yearMonth)

        val dutiesLastMonth = findDutyByMonthAndYear(
            member,
            calendarView.prevMonth.year,
            calendarView.prevMonth.monthValue
        ).associateBy { it.dutyDate.dayOfMonth }
        for (i in 1..calendarView.paddingBefore) {
            val day = calendarView.prevMonth.atEndOfMonth().dayOfMonth - (calendarView.paddingBefore - i)
            val duty = dutiesLastMonth[day]
            addDutyDto(calendarView.prevMonth, day, duty, answer, defaultDutyColor)
        }

        val dutiesOfMonth =
            findDutyByMonthAndYear(member, yearMonth.year, yearMonth.month.value)
                .associateBy { it.dutyDate.dayOfMonth }
        val lengthOfMonth = yearMonth.lengthOfMonth()
        for (i in 1..lengthOfMonth) {
            val duty = dutiesOfMonth[i]
            addDutyDto(yearMonth, i, duty, answer, defaultDutyColor)
        }

        val dutiesNextMonth = findDutyByMonthAndYear(
            member,
            calendarView.nextMonth.year,
            calendarView.nextMonth.monthValue
        ).associateBy { it.dutyDate.dayOfMonth }
        for (i in 1..calendarView.paddingAfter) {
            val duty = dutiesNextMonth[i]
            addDutyDto(calendarView.nextMonth, i, duty, answer, defaultDutyColor)
        }

        return answer
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

    private fun addDutyDto(
        yearMonth: YearMonth,
        day: Int,
        duty: Duty?,
        list: MutableList<DutyDto>,
        defaultDutyColor: Color
    ) {
        val dutyDto = DutyDto(
            year = yearMonth.year,
            month = yearMonth.month.value,
            day = day,
            dutyType = duty?.dutyType?.name,
            dutyColor = duty?.dutyType?.color?.name ?: defaultDutyColor.name
        )
        list.add(dutyDto)
    }

}
