package com.tistory.shanepark.dutypark.admin.service

import com.tistory.shanepark.dutypark.admin.domain.dto.AdminMemberDto
import com.tistory.shanepark.dutypark.admin.domain.dto.AdminMemberDetailDto
import com.tistory.shanepark.dutypark.member.domain.dto.DDayDto
import com.tistory.shanepark.dutypark.member.domain.enums.FriendRequestStatus
import com.tistory.shanepark.dutypark.member.domain.enums.SsoType
import com.tistory.shanepark.dutypark.member.repository.DDayRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRelationRepository
import com.tistory.shanepark.dutypark.member.repository.FriendRequestRepository
import com.tistory.shanepark.dutypark.member.repository.MemberManagerRepository
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.repository.RefreshTokenRepository
import com.tistory.shanepark.dutypark.member.service.MemberSocialAccountService
import com.tistory.shanepark.dutypark.notification.domain.repository.NotificationRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.security.config.DutyparkProperties
import com.tistory.shanepark.dutypark.todo.domain.entity.TodoStatus
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.springframework.data.domain.Page
import org.springframework.data.domain.PageImpl
import org.springframework.data.domain.Pageable
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDate
import java.time.LocalDateTime

@Service
@Transactional(readOnly = true)
class AdminService(
    private val memberRepository: MemberRepository,
    private val refreshTokenRepository: RefreshTokenRepository,
    private val scheduleRepository: ScheduleRepository,
    private val todoRepository: TodoRepository,
    private val friendRelationRepository: FriendRelationRepository,
    private val friendRequestRepository: FriendRequestRepository,
    private val memberManagerRepository: MemberManagerRepository,
    private val dDayRepository: DDayRepository,
    private val notificationRepository: NotificationRepository,
    private val memberSocialAccountService: MemberSocialAccountService,
    private val dutyparkProperties: DutyparkProperties,
) {

    fun findAllMembersWithTokens(keyword: String?, pageable: Pageable): Page<AdminMemberDto> {
        val memberPage = if (keyword.isNullOrBlank()) {
            memberRepository.findAllOrderByLastTokenAccess(pageable)
        } else {
            memberRepository.findByNameContainingOrderByLastTokenAccess(keyword, pageable)
        }

        val memberIds = memberPage.content.mapNotNull { it.id }
        val tokensByMemberId = refreshTokenRepository.findAllByMemberIdIn(memberIds)
            .groupBy { it.member.id!! }

        val adminMembers = memberPage.content.map { member ->
            AdminMemberDto.of(
                member = member,
                tokens = tokensByMemberId[member.id] ?: emptyList(),
            )
        }

        return PageImpl(adminMembers, pageable, memberPage.totalElements)
    }

    fun findMemberDetail(memberId: Long): AdminMemberDetailDto {
        val member = memberRepository.findMemberWithTeam(memberId).orElseThrow()
        val now = LocalDateTime.now()
        val today = LocalDate.now()

        val providers = memberSocialAccountService.findProviderMapByMemberIds(setOf(memberId))[memberId].orEmpty()
        val allTokens = refreshTokenRepository.findAllByMemberIdOrderByLastUsedDesc(memberId)
        val activeTokens = allTokens.filter { it.isValid() }
        val managerRelations = memberManagerRepository.findAllByManaged(member)
        val managedRelations = memberManagerRepository.findAllByManager(member)
        val team = member.team

        val authProviders = providers.keys
            .sortedBy(SsoType::name)
            .map(SsoType::name)

        return AdminMemberDetailDto(
            id = member.id!!,
            name = member.name,
            email = member.email,
            teamId = team?.id,
            teamName = team?.name,
            calendarVisibility = member.calendarVisibility,
            hasProfilePhoto = member.hasProfilePhoto(),
            profilePhotoVersion = member.profilePhotoVersion,
            serviceAdmin = member.email?.let(dutyparkProperties.adminEmails::contains) == true,
            teamAdmin = team?.isAdmin(member.id) == true,
            teamManager = team?.managers?.any { it.member.id == member.id } == true,
            auxiliaryAccount = member.email == null && member.password == null && authProviders.isEmpty(),
            hasPassword = member.password != null,
            authProviders = authProviders,
            createdDate = member.createdDate,
            lastModifiedDate = member.lastModifiedDate,
            activeSessionCount = activeTokens.size,
            pushEnabledSessionCount = activeTokens.count { it.hasPushSubscription() },
            lastActiveAt = allTokens.maxByOrNull { it.lastUsed }?.lastUsed,
            totalScheduleCount = scheduleRepository.countByMemberId(memberId),
            upcomingScheduleCount = scheduleRepository.countByMemberIdAndEndDateTimeGreaterThanEqual(memberId, now),
            taggedScheduleCount = scheduleRepository.countTaggedSchedulesByMemberId(memberId),
            totalTodoCount = todoRepository.countByMemberId(memberId),
            todoCount = todoRepository.countByMemberIdAndStatus(memberId, TodoStatus.TODO),
            inProgressTodoCount = todoRepository.countByMemberIdAndStatus(memberId, TodoStatus.IN_PROGRESS),
            doneTodoCount = todoRepository.countByMemberIdAndStatus(memberId, TodoStatus.DONE),
            overdueTodoCount = todoRepository.countByMemberIdAndStatusNotAndDueDateBefore(memberId, TodoStatus.DONE, today),
            dueTodayTodoCount = todoRepository.countByMemberIdAndStatusNotAndDueDate(memberId, TodoStatus.DONE, today),
            dDays = dDayRepository.findAllByMemberOrderByDate(member).map(DDayDto::of),
            friendCount = friendRelationRepository.countByMemberId(memberId),
            familyCount = friendRelationRepository.countByMemberIdAndIsFamilyTrue(memberId),
            pendingReceivedFriendRequestCount = friendRequestRepository.countByToMemberIdAndStatus(memberId, FriendRequestStatus.PENDING),
            pendingSentFriendRequestCount = friendRequestRepository.countByFromMemberIdAndStatus(memberId, FriendRequestStatus.PENDING),
            managerCount = managerRelations.size.toLong(),
            managedMemberCount = managedRelations.size.toLong(),
            managerNames = managerRelations.map { it.manager.name }.sorted(),
            managedMemberNames = managedRelations.map { it.managed.name }.sorted(),
            totalNotificationCount = notificationRepository.countByMemberId(memberId),
            unreadNotificationCount = notificationRepository.countByMemberIdAndIsReadFalse(memberId),
        )
    }

}
