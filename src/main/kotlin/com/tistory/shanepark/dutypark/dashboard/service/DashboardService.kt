package com.tistory.shanepark.dutypark.dashboard.service

import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendDetail
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardFriendInfo
import com.tistory.shanepark.dutypark.dashboard.domain.DashboardMyDetail
import com.tistory.shanepark.dutypark.duty.domain.dto.DutyDto
import com.tistory.shanepark.dutypark.duty.repository.DutyRepository
import com.tistory.shanepark.dutypark.member.domain.dto.FriendDto
import com.tistory.shanepark.dutypark.member.domain.dto.FriendRequestDto
import com.tistory.shanepark.dutypark.member.domain.dto.MemberDto
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRelation
import com.tistory.shanepark.dutypark.member.domain.entity.FriendRequest
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.Visibility
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
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
) {

    fun my(loginMember: LoginMember): DashboardMyDetail {
        val member = memberRepository.findMemberWithTeam(loginMember.id).orElseThrow()
        return DashboardMyDetail(
            member = MemberDto.of(member),
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

        val dutiesByMemberId = todayDutiesByMembers(friendRelations.map { it.friend })
        val schedulesByMemberId = todaySchedulesByFriends(loginMember, friendRelations)

        val friends = friendRelations
            .map {
                val friendId = it.friend.id ?: throw IllegalStateException("Friend id is null")
                DashboardFriendDetail(
                    member = FriendDto.of(it.friend),
                    duty = dutiesByMemberId[friendId],
                    schedules = schedulesByMemberId[friendId] ?: emptyList(),
                    isFamily = it.isFamily,
                    pinOrder = it.pinOrder
                )
            }.sorted()

        return DashboardFriendInfo(
            friends = friends,
            pendingRequestsFrom = pendingRequestsFrom.map { toFriendRequestDto(it) },
            pendingRequestsTo = pendingRequestsTo.map { toFriendRequestDto(it) },
        )
    }

    private fun toFriendRequestDto(request: FriendRequest): FriendRequestDto {
        return FriendRequestDto(
            id = request.id!!,
            fromMember = FriendDto.of(request.fromMember),
            toMember = FriendDto.of(request.toMember),
            status = request.status.name,
            createdAt = request.createdDate,
            requestType = request.requestType
        )
    }

    private fun todayDutiesByMembers(members: List<Member>): Map<Long, DutyDto?> {
        if (members.isEmpty()) {
            return emptyMap()
        }

        val today = LocalDate.now()
        val duties = dutyRepository.findByDutyDateAndMemberIn(today, members)
            .associateBy { it.member.id!! }

        return members.associate { member ->
            val memberId = member.id ?: throw IllegalStateException("Member id is null")
            if (member.team == null) {
                memberId to null
            } else {
                val duty = duties[memberId]
                val dto = duty
                    ?.takeIf { it.dutyType != null }
                    ?.let(::DutyDto)
                    ?: DutyDto(
                        year = today.year,
                        month = today.monthValue,
                        day = today.dayOfMonth,
                        dutyType = member.team!!.defaultDutyName,
                        dutyColor = member.team!!.defaultDutyColor,
                        isOff = true
                    )
                memberId to dto
            }
        }
    }

    private fun todaySchedulesByFriends(
        loginMember: LoginMember,
        friendRelations: List<FriendRelation>
    ): Map<Long, List<ScheduleDto>> {
        if (friendRelations.isEmpty()) {
            return emptyMap()
        }

        val today = LocalDate.now()
        val start = today.atStartOfDay()
        val end = today.atTime(23, 59, 59)
        val friends = friendRelations.map { it.friend }
        val visibilityMap = friendService.buildScheduleVisibilityMap(loginMember, friendRelations)

        val personalByMemberId = mutableMapOf<Long, MutableList<Schedule>>()
        val taggedByMemberId = mutableMapOf<Long, MutableList<Schedule>>()

        friends.groupBy { friend ->
            visibilityMap[friend.id] ?: Visibility.publicOnly()
        }.forEach { (visibilities, members) ->
            val groupMemberIds = members.mapNotNull { it.id }.toSet()
            val personal = scheduleRepository.findSchedulesOfMembersRangeIn(members, start, end, visibilities)
            personal.forEach { schedule ->
                val ownerId = schedule.member.id ?: return@forEach
                personalByMemberId.getOrPut(ownerId) { mutableListOf() }.add(schedule)
            }

            val tagged = scheduleRepository.findTaggedSchedulesOfMembersRangeIn(members, start, end, visibilities)
            tagged.forEach { schedule ->
                schedule.tags.forEach { tag ->
                    val tagMemberId = tag.member.id
                    if (tagMemberId != null && groupMemberIds.contains(tagMemberId)) {
                        taggedByMemberId.getOrPut(tagMemberId) { mutableListOf() }.add(schedule)
                    }
                }
            }
        }

        return friends.associate { friend ->
            val friendId = friend.id ?: throw IllegalStateException("Friend id is null")
            val personalSchedules = personalByMemberId[friendId].orEmpty()
            val taggedSchedules = taggedByMemberId[friendId].orEmpty()
            val schedules = personalSchedules.plus(taggedSchedules)
                .map { schedule -> ScheduleDto.ofSimple(friend, schedule, today) }
            friendId to schedules
        }
    }

}
