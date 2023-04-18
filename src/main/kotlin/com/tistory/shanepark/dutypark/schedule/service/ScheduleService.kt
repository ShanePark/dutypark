package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.time.YearMonth

@Service
@Transactional
class ScheduleService(
    private val scheduleRepository: ScheduleRepository,
) {
    fun findSchedulesByYearAndMonth(member: Member, yearMonth: YearMonth): Array<List<ScheduleDto>> {
        val (start, end) = getStartAndEndOfMonth(yearMonth)
        val schedules = scheduleRepository.findSchedulesOfMonth(member, start, end)
        return groupSchedulesByDay(yearMonth, schedules)
    }

    private fun getStartAndEndOfMonth(yearMonth: YearMonth): Pair<LocalDateTime, LocalDateTime> {
        val startOfMonth = LocalDateTime.of(yearMonth.year, yearMonth.monthValue, 1, 0, 0)
        val endOfMonth = startOfMonth.plusMonths(1).minusSeconds(1)
        return Pair(startOfMonth, endOfMonth)
    }

    private fun groupSchedulesByDay(yearMonth: YearMonth, schedules: List<Schedule>): Array<List<ScheduleDto>> {
        val totalDaysOfMonth = yearMonth.lengthOfMonth()
        val array = Array(totalDaysOfMonth) { emptyList<ScheduleDto>() }
        val schedules = schedules.map { ScheduleDto.of(yearMonth, it) }.flatten()

        schedules.forEach {
            val dayIndex = it.dayOfMonth - 1
            array[dayIndex] = array[dayIndex] + it
        }

        return array
    }

}
