package com.tistory.shanepark.dutypark.duty.service

import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyUpdateDto
import com.tistory.shanepark.dutypark.duty.domain.entity.Duty
import com.tistory.shanepark.dutypark.duty.domain.entity.DutyType
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.YearMonth

@Service
@Transactional
class DutyService(
    private val dutyRepository: DutyRepository,
    private val dutyTypeRepository: DutyTypeRepository,
    private val memberService: MemberService
) {

    @Transactional(readOnly = true)
    fun getDutiesAsMap(member: Member, year: Int, month: Int): Map<Int, DutyDto?> {
        return dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(member, year, month)
            .associate { it.dutyDay to DutyDto(it) }
    }

    fun update(dutyUpdateDto: DutyUpdateDto) {
        val member = memberService.findById(dutyUpdateDto.memberId)

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
                val duty = Duty(
                    member = member,
                    dutyYear = dutyUpdateDto.year,
                    dutyMonth = dutyUpdateDto.month,
                    dutyDay = dutyUpdateDto.day,
                    dutyType = dutyType
                )
                save(duty)
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
    fun getDuties(member: Member, yearMonth: YearMonth): List<DutyDto> {
        val answer = mutableListOf<DutyDto>()

        val lastMonth = yearMonth.minusMonths(1)
        val dutiesLastMonth = dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(
            member = member,
            year = lastMonth.year,
            month = lastMonth.monthValue
        ).associateBy { it.dutyDay }
        val paddingBefore = yearMonth.atDay(1).dayOfWeek.value % 7
        for (i in 1..paddingBefore) {
            val day = lastMonth.atEndOfMonth().dayOfMonth - (paddingBefore - i)
            val duty = dutiesLastMonth[day]
            addDutyDto(lastMonth, day, duty, answer)
        }

        val dutiesOfMonth =
            dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(member, yearMonth.year, yearMonth.month.value)
                .associateBy { it.dutyDay }
        val lengthOfMonth = yearMonth.lengthOfMonth()
        for (i in 1..lengthOfMonth) {
            val duty = dutiesOfMonth[i]
            addDutyDto(yearMonth, i, duty, answer)
        }

        val paddingAfter = 7 - (yearMonth.atDay(lengthOfMonth).dayOfWeek.value % 7 + 1)
        val nextMonth = yearMonth.plusMonths(1)
        val dutiesNextMonth = dutyRepository.findAllByMemberAndDutyYearAndDutyMonth(
            member = member,
            year = nextMonth.year,
            month = nextMonth.monthValue
        ).associateBy { it.dutyDay }
        for (i in 1..paddingAfter) {
            val duty = dutiesNextMonth[i]
            addDutyDto(nextMonth, i, duty, answer)
        }

        return answer
    }

    private fun addDutyDto(yearMonth: YearMonth, day: Int, duty: Duty?, list: MutableList<DutyDto>) {
        val dutyDto = DutyDto(
            year = yearMonth.year,
            month = yearMonth.month.value,
            day = day,
            dutyType = duty?.dutyType?.name,
            dutyColor = duty?.dutyType?.color.toString()
        )
        list.add(dutyDto)
    }

}
