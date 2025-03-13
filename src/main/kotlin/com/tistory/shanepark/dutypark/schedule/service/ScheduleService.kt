package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.DutyparkAuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingQueueManager
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
    private val friendService: FriendService,
    private val memberService: MemberService,
    private val scheduleTimeParsingQueueManager: ScheduleTimeParsingQueueManager,
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun findSchedulesByYearAndMonth(
        loginMember: LoginMember?,
        memberId: Long,
        yearMonth: YearMonth
    ): Array<List<ScheduleDto>> {
        val member = memberRepository.findById(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member, scheduleVisibilityCheck = true)

        val calendarView = CalendarView(yearMonth)

        val paddingBefore = calendarView.paddingBefore
        val lengthOfMonth = calendarView.lengthOfMonth

        val array = Array<List<ScheduleDto>>(paddingBefore + lengthOfMonth + calendarView.paddingAfter) { emptyList() }
        val start = calendarView.rangeFromDateTime
        val end = calendarView.rangeUntilDateTime

        val availableVisibilities = friendService.availableScheduleVisibilities(loginMember, member)

        val userSchedules =
            scheduleRepository.findSchedulesOfMonth(member, start, end, visibilities = availableVisibilities)
                .map { ScheduleDto.of(calendarView, it, isTagged = false) }

        val taggedSchedules =
            scheduleRepository.findTaggedSchedulesOfRange(member, start, end, visibilities = availableVisibilities)
                .map { ScheduleDto.of(calendarView, it, isTagged = true) }

        userSchedules.plus(taggedSchedules)
            .flatten()
            .sortedWith(compareBy({ it.isTagged }, { it.position }, { it.startDateTime.toLocalDate() }))
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

    fun createSchedule(loginMember: LoginMember, scheduleSaveDto: ScheduleSaveDto): Schedule {
        val scheduleMember = memberRepository.findById(scheduleSaveDto.memberId).orElseThrow()
        checkScheduleAuthority(loginMember, scheduleMember)

        val startDateTime = scheduleSaveDto.startDateTime
        val position = findNextPosition(scheduleMember, startDateTime)
        val schedule = Schedule(
            member = scheduleMember,
            content = scheduleSaveDto.content,
            description = scheduleSaveDto.description,
            startDateTime = startDateTime,
            endDateTime = scheduleSaveDto.endDateTime,
            position = position,
            visibility = scheduleSaveDto.visibility
        )

        log.info("create schedule: $scheduleSaveDto")
        scheduleRepository.save(schedule)
        scheduleTimeParsingQueueManager.addTask(schedule)
        return schedule
    }

    private fun findNextPosition(
        member: Member,
        startDateTime: LocalDateTime
    ) = scheduleRepository.findMaxPosition(member, startDateTime) + 1

    fun updateSchedule(loginMember: LoginMember, scheduleSaveDto: ScheduleSaveDto): Schedule {
        if (scheduleSaveDto.id == null)
            throw IllegalArgumentException("Schedule id must not be null to update")

        val schedule = scheduleRepository.findById(scheduleSaveDto.id).orElseThrow()
        checkScheduleAuthority(schedule = schedule, loginMember = loginMember)

        schedule.startDateTime = scheduleSaveDto.startDateTime
        schedule.endDateTime = scheduleSaveDto.endDateTime
        schedule.content = scheduleSaveDto.content
        schedule.description = scheduleSaveDto.description
        schedule.visibility = scheduleSaveDto.visibility
        schedule.parsingTimeStatus = ParsingTimeStatus.WAIT

        log.info("update schedule: $scheduleSaveDto")
        scheduleRepository.save(schedule)
        scheduleTimeParsingQueueManager.addTask(schedule)
        return schedule
    }

    fun swapSchedulePosition(loginMember: LoginMember, schedule1Id: UUID, schedule2Id: UUID) {
        val schedule1 = scheduleRepository.findById(schedule1Id).orElseThrow()
        val schedule2 = scheduleRepository.findById(schedule2Id).orElseThrow()

        if (schedule1.startDateTime.toLocalDate() != schedule2.startDateTime.toLocalDate()) {
            throw IllegalArgumentException("Schedule must have same date")
        }

        checkScheduleAuthority(schedule = schedule1, loginMember = loginMember)
        checkScheduleAuthority(schedule = schedule2, loginMember = loginMember)

        schedule1.position = schedule2.position.also { schedule2.position = schedule1.position }
    }

    fun deleteSchedule(loginMember: LoginMember, id: UUID) {
        val schedule = scheduleRepository.findById(id).orElseThrow()
        checkScheduleAuthority(schedule = schedule, loginMember = loginMember)

        scheduleRepository.delete(schedule)
    }

    fun tagFriend(loginMember: LoginMember, scheduleId: UUID, friendId: Long) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val friend = memberRepository.findById(friendId).orElseThrow()
        val login = memberRepository.findById(loginMember.id).orElseThrow()

        checkScheduleAuthority(schedule = schedule, loginMember = loginMember)

        if (!friendService.isFriend(login, friend)) {
            throw DutyparkAuthException("$friend is not friend of $loginMember")
        }

        schedule.addTag(friend)
    }

    fun untagFriend(loginMember: LoginMember, scheduleId: UUID, memberId: Long) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()
        checkScheduleAuthority(schedule = schedule, loginMember = loginMember)

        schedule.removeTag(member)
    }

    fun untagSelf(loginMember: LoginMember, scheduleId: UUID) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        schedule.removeTag(member)
    }

    private fun checkScheduleAuthority(loginMember: LoginMember, scheduleMember: Member) {
        if (scheduleMember.isEquals(loginMember = loginMember)) return
        if (memberService.isManager(isManager = loginMember, target = scheduleMember)) return

        throw DutyparkAuthException("login member doesn't have permission to create or edit the schedule")
    }

    private fun checkScheduleAuthority(loginMember: LoginMember, schedule: Schedule) {
        checkScheduleAuthority(loginMember, schedule.member)
    }

}
