package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
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
        return dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(member, year, month)
            .associate { it.dutyDay to DutyDto(it) }
    }

    fun update(dutyUpdateDto: DutyUpdateDto) {
        val member = memberRepository.findById(dutyUpdateDto.memberId).orElseThrow()

        val duty: Duty? = dutyRepository.findByMemberAndDutyYearAndDutyMonthAndDutyDay(
            member = member,
            year = dutyUpdateDto.year,
            month = dutyUpdateDto.month,
            day = dutyUpdateDto.day
        )

        val dutyType: DutyType? = dutyUpdateDto.dutyTypeId?.let {
            dutyTypeRepository.findById(it).orElseThrow()
        }

        if (duty == null) {
            if (dutyType != null) {
                save(
                    Duty(
                        member = member,
                        dutyYear = dutyUpdateDto.year,
                        dutyMonth = dutyUpdateDto.month,
                        dutyDay = dutyUpdateDto.day,
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

    fun save(duty: Duty): Duty {
        return dutyRepository.save(duty)
    }

    fun canEdit(
        loginMember: LoginMember, member: Member
    ): Boolean {
        if (member.id == loginMember.id) {
            return true
        }
        if (member.department?.manager?.id == loginMember.id) {
            return true
        }
        return false
    }

    @Transactional(readOnly = true)
    fun getDuties(memberId: Long, yearMonth: YearMonth, loginMember: LoginMember): List<DutyDto> {
        val member = memberRepository.findMemberWithDepartment(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member)
        val department = member.department ?: return emptyList()
        val offColor = department.offColor

        val answer = mutableListOf<DutyDto>()
        val calendarView = CalendarView(yearMonth)

        val dutiesLastMonth = dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(
            member = member,
            year = calendarView.prevMonth.year,
            month = calendarView.prevMonth.monthValue
        ).associateBy { it.dutyDay }
        for (i in 1..calendarView.paddingBefore) {
            val day = calendarView.prevMonth.atEndOfMonth().dayOfMonth - (calendarView.paddingBefore - i)
            val duty = dutiesLastMonth[day]
            addDutyDto(calendarView.prevMonth, day, duty, answer, offColor)
        }

        val dutiesOfMonth =
            dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(member, yearMonth.year, yearMonth.month.value)
                .associateBy { it.dutyDay }
        val lengthOfMonth = yearMonth.lengthOfMonth()
        for (i in 1..lengthOfMonth) {
            val duty = dutiesOfMonth[i]
            addDutyDto(yearMonth, i, duty, answer, offColor)
        }

        val dutiesNextMonth = dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(
            member = member,
            year = calendarView.nextMonth.year,
            month = calendarView.nextMonth.monthValue
        ).associateBy { it.dutyDay }
        for (i in 1..calendarView.paddingAfter) {
            val duty = dutiesNextMonth[i]
            addDutyDto(calendarView.nextMonth, i, duty, answer, offColor)
        }

        return answer
    }

    private fun addDutyDto(yearMonth: YearMonth, day: Int, duty: Duty?, list: MutableList<DutyDto>, offColor: Color) {
        val dutyDto = DutyDto(
            year = yearMonth.year,
            month = yearMonth.month.value,
            day = day,
            dutyType = duty?.dutyType?.name,
            dutyColor = duty?.dutyType?.color?.name ?: offColor.name
        )
        list.add(dutyDto)
    }

}
