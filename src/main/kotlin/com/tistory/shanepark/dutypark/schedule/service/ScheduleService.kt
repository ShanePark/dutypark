package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleUpdateDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.time.YearMonth
import java.util.*

@Service
@Transactional
class ScheduleService(
    private val scheduleRepository: ScheduleRepository,
    private val memberRepository: MemberRepository,
) {

    @Transactional(readOnly = true)
    fun findSchedulesByYearAndMonth(member: Member, yearMonth: YearMonth): Array<List<ScheduleDto>> {
        val calendarView = CalendarView(yearMonth)

        val paddingBefore = calendarView.paddingBefore
        val lengthOfMonth = calendarView.lengthOfMonth

        val array = Array<List<ScheduleDto>>(paddingBefore + lengthOfMonth + calendarView.paddingAfter) { emptyList() }
        val start = calendarView.rangeFrom
        val end = calendarView.rangeEnd

        scheduleRepository.findSchedulesOfMonth(member, start, end)
            .map { ScheduleDto.of(calendarView, it) }
            .flatten()
            .sortedWith(compareBy({ it.startDateTime.toLocalDate() }, { it.position }))
            .forEach { scheduleDto ->
                var dayIndex = paddingBefore + scheduleDto.dayOfMonth - 1
                if (scheduleDto.month < yearMonth.monthValue) {
                    dayIndex -= calendarView.prevMonth.lengthOfMonth()
                }
                if (scheduleDto.month > yearMonth.monthValue) {
                    dayIndex += lengthOfMonth
                }

                array[dayIndex] = array[dayIndex] + scheduleDto
            }
        return array
    }

    fun createSchedule(scheduleUpdateDto: ScheduleUpdateDto): Schedule {
        val member = memberRepository.findById(scheduleUpdateDto.memberId).orElseThrow()
        val startDateTime = scheduleUpdateDto.startDateTime
        val endDateTime = scheduleUpdateDto.endDateTime

        val position = nextPosition(member, startDateTime)

        val schedule = Schedule(
            member = member,
            content = scheduleUpdateDto.content,
            startDateTime = startDateTime,
            endDateTime = endDateTime,
            position = position
        )
        return scheduleRepository.save(schedule)
    }

    private fun nextPosition(
        member: Member,
        startDateTime: LocalDateTime
    ) = scheduleRepository.findMaxPosition(member, startDateTime) + 1

    fun updateSchedule(id: UUID, scheduleUpdateDto: ScheduleUpdateDto): Schedule {
        val schedule = scheduleRepository.findById(id).orElseThrow()
        schedule.startDateTime = scheduleUpdateDto.startDateTime
        schedule.endDateTime = scheduleUpdateDto.endDateTime
        schedule.content = scheduleUpdateDto.content
        return scheduleRepository.save(schedule)
    }

    fun swapSchedulePosition(schedule1: Schedule, schedule2: Schedule) {
        if (schedule1.startDateTime.toLocalDate() != schedule2.startDateTime.toLocalDate()) {
            throw IllegalArgumentException("Schedule must have same date")
        }

        schedule1.position = schedule2.position.also { schedule2.position = schedule1.position }
    }

    fun deleteSchedule(id: UUID) {
        val schedule = scheduleRepository.findById(id).orElseThrow()
        scheduleRepository.delete(schedule)
    }

    @Transactional(readOnly = true)
    fun checkAuthentication(loginMember: LoginMember, targetMemberId: Long) {
        val targetMember = memberRepository.findMemberWithDepartment(targetMemberId).orElseThrow()

        if (targetMember.id == loginMember.id)
            return
        if (targetMember.department?.manager?.id == loginMember.id)
            return

        throw DutyparkAuthException("login member doesn't have permission to update schedule")
    }

}
