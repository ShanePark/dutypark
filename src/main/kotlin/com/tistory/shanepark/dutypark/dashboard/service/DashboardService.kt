package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardDepartment
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendDetail
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendInfo
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardMyDetail
import com.tistory.shanepark.dutypark.department.service.DepartmentService
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.dto.FriendRequestDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
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
    private val friendRelationRepository: FriendRelationRepository,
    private val friendService: FriendService,
    private val departmentService: DepartmentService,
) {

    fun my(loginMember: LoginMember): DashboardMyDetail {
        val member = memberRepository.findMemberWithDepartment(loginMember.id).orElseThrow()
        return DashboardMyDetail(
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

    fun department(loginMember: LoginMember): DashboardDepartment {
        val member = memberRepository.findMemberWithDepartment(loginMember.id).orElseThrow()
        val departmentId = member.department?.id ?: return DashboardDepartment(department = null, groups = emptyList())
        return departmentService.dashboardDepartment(departmentId)
    }

    fun friend(loginMember: LoginMember): DashboardFriendInfo {
        val member = memberRepository.findMemberWithDepartment(loginMember.id).orElseThrow()
        val friends = friendRelationRepository.findAllByMember(member)
            .map {
                DashboardFriendDetail(
                    member = MemberDto.of(it.friend),
                    duty = todayDuty(it.friend),
                    schedules = todaySchedules(it.friend),
                    isFamily = it.isFamily,
                    pinOrder = it.pinOrder
                )
            }.sorted()
        val pendingRequestsTo = friendService.getPendingRequestsTo(member).map { FriendRequestDto.of(it) }
        val pendingRequestsFrom = friendService.getPendingRequestsFrom(member).map { FriendRequestDto.of(it) }
        return DashboardFriendInfo(
            friends = friends,
            pendingRequestsFrom = pendingRequestsFrom,
            pendingRequestsTo = pendingRequestsTo,
        )
    }

}
