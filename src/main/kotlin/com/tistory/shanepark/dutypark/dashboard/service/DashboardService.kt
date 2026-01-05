package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendDetail
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendInfo
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardMyDetail
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.dto.FriendDto
import com.tistory.shanepark.dutypark.member.domain.dto.FriendRequestDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.member.service.ProfilePhotoService
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
    private val profilePhotoService: ProfilePhotoService,
) {

    fun my(loginMember: LoginMember): DashboardMyDetail {
        val member = memberRepository.findMemberWithTeam(loginMember.id).orElseThrow()
        val hasProfilePhoto = profilePhotoService.hasProfilePhoto(member.id!!)
        return DashboardMyDetail(
            member = MemberDto.of(member, hasProfilePhoto),
            duty = todayDuty(member),
            schedules = todaySchedules(loginMember = loginMember, member = member),
        )
    }

    private fun todaySchedules(loginMember: LoginMember, member: Member): List<ScheduleDto> {
        val today = LocalDate.now()
        val visibilities = friendService.availableScheduleVisibilities(loginMember = loginMember, member = member)

        val personal = scheduleRepository.findSchedulesOfMemberRangeIn(
            member = member,
            start = today.atStartOfDay(),
            end = today.atTime(23, 59, 59),
            visibilities = visibilities
        )
        val tagged = scheduleRepository.findTaggedSchedulesOfRange(
            taggedMember = member,
            start = today.atStartOfDay(),
            end = today.atTime(23, 59, 59),
            visibilities = visibilities
        )
        return personal.plus(tagged)
            .map { schedule -> ScheduleDto.ofSimple(member, schedule, today) }
    }

    private fun todayDuty(member: Member): DutyDto? {
        val team = member.team ?: return null
        val today = LocalDate.now()
        return dutyRepository.findByMemberAndDutyDate(member, today)
            ?.takeIf { it.dutyType != null }?.let(::DutyDto)
            ?: DutyDto(
                year = today.year,
                month = today.monthValue,
                day = today.dayOfMonth,
                dutyType = team.defaultDutyName,
                dutyColor = team.defaultDutyColor,
                isOff = true
            )
    }

    fun friend(loginMember: LoginMember): DashboardFriendInfo {
        val member = memberRepository.findMemberWithTeam(loginMember.id).orElseThrow()
        val friendRelations = friendRelationRepository.findAllByMember(member)
        val pendingRequestsTo = friendService.getPendingRequestsTo(member)
        val pendingRequestsFrom = friendService.getPendingRequestsFrom(member)

        val allMemberIds = mutableListOf<Long>()
        allMemberIds.addAll(friendRelations.mapNotNull { it.friend.id })
        allMemberIds.addAll(pendingRequestsTo.mapNotNull { it.fromMember.id })
        allMemberIds.addAll(pendingRequestsTo.mapNotNull { it.toMember.id })
        allMemberIds.addAll(pendingRequestsFrom.mapNotNull { it.fromMember.id })
        allMemberIds.addAll(pendingRequestsFrom.mapNotNull { it.toMember.id })
        val membersWithPhoto = profilePhotoService.getMembersWithProfilePhoto(allMemberIds)

        val friends = friendRelations
            .map {
                DashboardFriendDetail(
                    member = FriendDto.of(it.friend, it.friend.id in membersWithPhoto),
                    duty = todayDuty(it.friend),
                    schedules = todaySchedules(loginMember = loginMember, member = it.friend),
                    isFamily = it.isFamily,
                    pinOrder = it.pinOrder
                )
            }.sorted()

        return DashboardFriendInfo(
            friends = friends,
            pendingRequestsFrom = pendingRequestsFrom.map { toFriendRequestDto(it, membersWithPhoto) },
            pendingRequestsTo = pendingRequestsTo.map { toFriendRequestDto(it, membersWithPhoto) },
        )
    }

    private fun toFriendRequestDto(request: FriendRequest, membersWithPhoto: Set<Long>): FriendRequestDto {
        return FriendRequestDto(
            id = request.id!!,
            fromMember = FriendDto.of(request.fromMember, request.fromMember.id in membersWithPhoto),
            toMember = FriendDto.of(request.toMember, request.toMember.id in membersWithPhoto),
            status = request.status.name,
            createdAt = request.createdDate,
            requestType = request.requestType
        )
    }

}
