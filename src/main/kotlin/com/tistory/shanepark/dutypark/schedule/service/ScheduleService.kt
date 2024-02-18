package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
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
    private val friendService: FriendService
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
                val isPreviousMonth =
                    scheduleDto.year * 12 + scheduleDto.month < yearMonth.year * 12 + yearMonth.monthValue
                if (isPreviousMonth) {
                    dayIndex -= calendarView.prevMonth.lengthOfMonth()
                }
                val isNextMonth = scheduleDto.year * 12 + scheduleDto.month > yearMonth.year * 12 + yearMonth.monthValue
                if (isNextMonth) {
                    dayIndex += lengthOfMonth
                }

                array[dayIndex] = array[dayIndex] + scheduleDto
            }
        return array
    }

    fun createSchedule(loginMember: LoginMember, scheduleUpdateDto: ScheduleUpdateDto): Schedule {
        val scheduleMember = memberRepository.findById(scheduleUpdateDto.memberId).orElseThrow()

        checkScheduleCreateAuthority(loginMember, scheduleMember)

        val startDateTime = scheduleUpdateDto.startDateTime
        val endDateTime = scheduleUpdateDto.endDateTime

        val position = nextPosition(scheduleMember, startDateTime)

        val schedule = Schedule(
            member = scheduleMember,
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

    fun updateSchedule(loginMember: LoginMember, id: UUID, scheduleUpdateDto: ScheduleUpdateDto): Schedule {
        val schedule = scheduleRepository.findById(id).orElseThrow()
        checkScheduleUpdateAuthority(schedule = schedule, loginMember = loginMember)

        schedule.startDateTime = scheduleUpdateDto.startDateTime
        schedule.endDateTime = scheduleUpdateDto.endDateTime
        schedule.content = scheduleUpdateDto.content
        return scheduleRepository.save(schedule)
    }

    fun swapSchedulePosition(loginMember: LoginMember, schedule1: Schedule, schedule2: Schedule) {
        if (schedule1.startDateTime.toLocalDate() != schedule2.startDateTime.toLocalDate()) {
            throw IllegalArgumentException("Schedule must have same date")
        }

        checkScheduleUpdateAuthority(schedule = schedule1, loginMember = loginMember)
        checkScheduleUpdateAuthority(schedule = schedule2, loginMember = loginMember)

        schedule1.position = schedule2.position.also { schedule2.position = schedule1.position }
    }

    fun deleteSchedule(loginMember: LoginMember, id: UUID) {
        val schedule = scheduleRepository.findById(id).orElseThrow()

        checkScheduleUpdateAuthority(schedule = schedule, loginMember = loginMember)

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

    fun tagFriend(loginMember: LoginMember, scheduleId: UUID, friendId: Long) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val friend = memberRepository.findById(friendId).orElseThrow()

        checkScheduleUpdateAuthority(schedule = schedule, loginMember = loginMember)

        if (!friendService.isFriend(loginMember.id, friendId)) {
            throw DutyparkAuthException("$friend is not friend of $loginMember")
        }

        schedule.addTag(friend)
    }

    fun untagFriend(loginMember: LoginMember, scheduleId: UUID, memberId: Long) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()

        checkScheduleUpdateAuthority(schedule = schedule, loginMember = loginMember)

        schedule.removeTag(member)
    }

    private fun checkScheduleCreateAuthority(loginMember: LoginMember, scheduleMember: Member) {
        if (loginMember.id == scheduleMember.id)
            return

        if (scheduleMember.department?.manager?.id == loginMember.id)
            return

        throw DutyparkAuthException("login member doesn't have permission to create the schedule")
    }

    private fun checkScheduleUpdateAuthority(
        loginMember: LoginMember,
        schedule: Schedule,
    ) {
        if (schedule.member.id == loginMember.id) {
            return
        }

        if (isDepartmentManager(schedule, loginMember)) {
            return
        }

        throw DutyparkAuthException("login member doesn't have permission to update schedule")
    }

    private fun isDepartmentManager(
        schedule: Schedule,
        loginMember: LoginMember
    ) = schedule.member.department?.manager?.id == loginMember.id

}
