package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.dashboard.domain.*
import com.tistory.shanepark.dutypark.department.domain.dto.DepartmentDto
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.duty.repository.DutyTypeRepository
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
    private val dutyTypeRepository: DutyTypeRepository,
    private val friendRelationRepository: FriendRelationRepository,
    private val friendService: FriendService,
) {

    fun my(loginMember: LoginMember): DashboardPerson {
        val member = memberRepository.findMemberWithDepartment(loginMember.id).orElseThrow()
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

    fun department(loginMember: LoginMember): DashboardDepartment {
        val member = memberRepository.findMemberWithDepartment(loginMember.id).orElseThrow()
        val department = member.department ?: return DashboardDepartment(department = null, groups = emptyList())

        val departmentMembers = memberRepository.findMembersByDepartment(department)

        val dutyMemberMap = dutyRepository.findByDutyDateAndMemberIn(LocalDate.now(), departmentMembers)
            .associateBy({ it }, { it.member })
        val offMembers = departmentMembers.filterNot { m -> dutyMemberMap.containsValue(m) }

        val dutyTypes = dutyTypeRepository.findAllByDepartment(department)
        val dutyTypeMembers = DepartmentDto.of(department, departmentMembers, dutyTypes)
            .dutyTypes
            .map { dutyTypeDto ->
                val members = dutyTypeDto.id?.let { dutyType ->
                    dutyMemberMap
                        .filter { (duty, _) -> duty.dutyType.id == dutyType }
                        .map { (_, member) -> DashboardSimpleMember(member.id, member.name) }
                } ?: offMembers.map { member -> DashboardSimpleMember(member.id, member.name) }
                DashboardDutyType(dutyTypeDto, members)
            }

        return DashboardDepartment(
            department = DepartmentDto.ofSimple(department),
            groups = dutyTypeMembers
        )
    }

    fun friend(loginMember: LoginMember): DashboardFriendInfo {
        val member = memberRepository.findMemberWithDepartment(loginMember.id).orElseThrow()
        val friends = friendRelationRepository.findAllByMember(member)
            .map {
                DashboardPerson(
                    member = MemberDto.of(it.friend),
                    duty = todayDuty(it.friend),
                    schedules = todaySchedules(it.friend),
                )
            }
        val pendingRequestsTo = friendService.getPendingRequestsTo(member).map { FriendRequestDto.of(it) }
        val pendingRequestsFrom = friendService.getPendingRequestsFrom(member).map { FriendRequestDto.of(it) }
        return DashboardFriendInfo(
            friends = friends,
            pendingRequestsFrom = pendingRequestsFrom,
            pendingRequestsTo = pendingRequestsTo,
        )
    }

}
