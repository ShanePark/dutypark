package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardPerson
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate

@Service
@Transactional(readOnly = true)
class DashboardService(
    private val memberRepository: MemberRepository,
    private val dutyRepository: DutyRepository,
    private val scheduleRepository: ScheduleRepository,
) {

    fun my(loginMember: LoginMember): DashboardPerson {
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        return DashboardPerson(
            member = MemberDto.of(member),
            duty = todayDuty(member),
            schedules = todaySchedules(member),
        )
    }

    private fun todaySchedules(member: Member): List<ScheduleDto> {
        return scheduleRepository.findTodaySchedulesByMember(member)
            .map { schedule -> ScheduleDto.ofSimple(member, schedule) }
    }

    private fun todayDuty(member: Member): DutyDto? {
        val department = member.department ?: return null
        val today = LocalDate.now()
        val duty = dutyRepository.findByMemberAndDutyDate(member, today)
        return duty?.let(::DutyDto) ?: DutyDto(
            year = today.year,
            month = today.monthValue,
            day = today.dayOfMonth,
            dutyType = department.defaultDutyName,
            dutyColor = department.defaultDutyColor.toString()
        )
    }


    // TODO
    fun friend(loginMember: LoginMember): List<DashboardPerson> {
        return emptyList()
    }

    // TODO
    fun department(loginMember: LoginMember): List<DashboardPerson> {
        return emptyList()
    }


}
