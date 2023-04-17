package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime

@Service
@Transactional
class ScheduleService(
    private val scheduleRepository: ScheduleRepository,
) {

    fun findSchedulesByYearAndMonth(member: Member, year: Int, month: Int) {
        val startOfMonth = LocalDateTime.of(year, month, 1, 0, 0)
        val endOfMonth = startOfMonth.plusMonths(1).minusSeconds(1)
        val schedules = scheduleRepository.findSchedulesForMonth(member, startOfMonth, endOfMonth)
    }

}
