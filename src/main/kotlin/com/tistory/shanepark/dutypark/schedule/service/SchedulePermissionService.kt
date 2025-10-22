package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.MemberService
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.stereotype.Service
import java.util.*

@Service
class SchedulePermissionService(
    private val scheduleRepository: ScheduleRepository,
    private val friendService: FriendService,
    private val memberService: MemberService
) {
    fun checkScheduleWriteAuthority(loginMember: LoginMember, scheduleMember: Member) {
        if (scheduleMember.isEquals(loginMember = loginMember)) return
        if (memberService.isManager(isManager = loginMember, target = scheduleMember)) return

        throw AuthException("login member doesn't have permission to create or edit the schedule")
    }

    fun checkScheduleWriteAuthority(loginMember: LoginMember, schedule: Schedule) {
        checkScheduleWriteAuthority(loginMember, schedule.member)
    }

    fun checkScheduleWriteAuthority(loginMember: LoginMember, scheduleId: UUID) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        checkScheduleWriteAuthority(loginMember, schedule.member)
    }

    fun checkScheduleReadAuthority(loginMember: LoginMember?, scheduleId: UUID) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        friendService.checkVisibility(loginMember, schedule.member, scheduleVisibilityCheck = true)

        val availableVisibilities = friendService.availableScheduleVisibilities(loginMember, schedule.member)
        if (schedule.visibility !in availableVisibilities) {
            throw AuthException("Schedule visibility ${schedule.visibility} is not accessible")
        }
    }
}
