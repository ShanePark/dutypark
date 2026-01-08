package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType.SCHEDULE
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.attachment.service.FileSystemService
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.AuthException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.notification.event.ScheduleTaggedEvent
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingQueueManager
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.context.ApplicationEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.util.*

@Service
@Transactional
class ScheduleService(
    private val scheduleRepository: ScheduleRepository,
    private val memberRepository: MemberRepository,
    private val friendService: FriendService,
    private val scheduleTimeParsingQueueManager: ScheduleTimeParsingQueueManager,
    private val schedulePermissionService: SchedulePermissionService,
    private val attachmentRepository: AttachmentRepository,
    private val attachmentService: AttachmentService,
    private val fileSystemService: FileSystemService,
    private val pathResolver: StoragePathResolver,
    private val eventPublisher: ApplicationEventPublisher,
) {
    private val log = logger()

    @Transactional(readOnly = true)
    fun findSchedulesByYearAndMonth(
        loginMember: LoginMember?,
        memberId: Long,
        year: Int,
        month: Int,
    ): Array<List<ScheduleDto>> {
        val member = memberRepository.findById(memberId).orElseThrow()
        friendService.checkVisibility(loginMember, member, scheduleVisibilityCheck = true)

        val calendarView = CalendarView(year = year, month = month)

        val array = calendarView.makeCalendarArray<ScheduleDto>()

        val start = calendarView.rangeFromDateTime
        val end = calendarView.rangeUntilDateTime

        val availableVisibilities = friendService.availableScheduleVisibilities(loginMember, member)

        val userSchedules =
            scheduleRepository.findSchedulesOfMemberRangeIn(member, start, end, visibilities = availableVisibilities)
                .map { ScheduleDto.of(calendarView, it, isTagged = false) }

        val taggedSchedules =
            scheduleRepository.findTaggedSchedulesOfRange(member, start, end, visibilities = availableVisibilities)
                .map { ScheduleDto.of(calendarView, it, isTagged = true) }

        val allScheduleDtos = userSchedules.plus(taggedSchedules).flatten()

        val scheduleIds = allScheduleDtos.map { it.id.toString() }.distinct()
        val attachmentsByScheduleId = if (scheduleIds.isNotEmpty()) {
            attachmentRepository.findAllByContextTypeAndContextIdIn(SCHEDULE, scheduleIds)
                .map { com.tistory.shanepark.dutypark.attachment.dto.AttachmentDto.from(it) }
                .groupBy { it.contextId }
        } else {
            emptyMap()
        }

        allScheduleDtos
            .map { dto ->
                val attachments = attachmentsByScheduleId[dto.id.toString()] ?: emptyList()
                dto.copy(attachments = attachments)
            }
            .sortedWith(compareBy({ it.isTagged }, { it.position }, { it.startDateTime.toLocalDate() }))
            .forEach { scheduleDto ->
                if (!calendarView.isInRange(scheduleDto.curDate))
                    return@forEach
                val dayIndex = calendarView.getIndex(scheduleDto.curDate)
                array[dayIndex] = array[dayIndex] + scheduleDto
            }

        return array
    }

    @Transactional(readOnly = true)
    fun getScheduleBasicInfo(loginMember: LoginMember?, scheduleId: UUID): Map<String, Any> {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val owner = schedule.member
        val isTagged = loginMember != null && schedule.tags.any { it.member.id == loginMember.id }

        if (!isTagged) {
            friendService.checkVisibility(loginMember, owner, scheduleVisibilityCheck = true)
        }

        return mapOf(
            "id" to schedule.id.toString(),
            "memberId" to owner.id!!,
            "memberName" to owner.name,
            "startDateTime" to schedule.startDateTime.toString(),
            "content" to schedule.content
        )
    }

    fun createSchedule(loginMember: LoginMember, scheduleSaveDto: ScheduleSaveDto): Schedule {
        val scheduleMember = memberRepository.findById(scheduleSaveDto.memberId).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(loginMember, scheduleMember)

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

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = SCHEDULE,
            contextId = schedule.id.toString(),
            attachmentSessionId = scheduleSaveDto.attachmentSessionId,
            orderedAttachmentIds = scheduleSaveDto.orderedAttachmentIds
        )

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
        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        schedule.startDateTime = scheduleSaveDto.startDateTime
        schedule.endDateTime = scheduleSaveDto.endDateTime
        schedule.content = scheduleSaveDto.content
        schedule.description = scheduleSaveDto.description
        schedule.visibility = scheduleSaveDto.visibility
        schedule.parsingTimeStatus = ParsingTimeStatus.WAIT

        log.info("update schedule: $scheduleSaveDto")
        scheduleRepository.save(schedule)
        scheduleTimeParsingQueueManager.addTask(schedule)

        val scheduleId = schedule.id.toString()
        val orderedIds = scheduleSaveDto.orderedAttachmentIds

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = SCHEDULE,
            contextId = scheduleId,
            attachmentSessionId = scheduleSaveDto.attachmentSessionId,
            orderedAttachmentIds = orderedIds
        )

        return schedule
    }

    fun reorderSchedulePositions(loginMember: LoginMember, scheduleIds: List<UUID>) {
        if (scheduleIds.isEmpty()) return

        val schedules = scheduleIds.mapNotNull { scheduleRepository.findById(it).orElse(null) }
        if (schedules.size != scheduleIds.size) {
            throw IllegalArgumentException("Some schedules not found")
        }

        val firstDate = schedules.first().startDateTime.toLocalDate()
        if (!schedules.all { it.startDateTime.toLocalDate() == firstDate }) {
            throw IllegalArgumentException("All schedules must have same date")
        }

        schedules.forEach { schedule ->
            schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)
        }

        scheduleIds.forEachIndexed { index, scheduleId ->
            val schedule = schedules.find { it.id == scheduleId }!!
            schedule.position = index
        }
    }

    fun deleteSchedule(loginMember: LoginMember, id: UUID) {
        val schedule = scheduleRepository.findById(id).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        val contextId = id.toString()
        val attachments = attachmentRepository.findAllByContextTypeAndContextId(SCHEDULE, contextId)

        attachments.forEach(attachmentService::deleteAttachment)

        val contextDir = pathResolver.resolveContextDirectory(SCHEDULE, contextId)
        fileSystemService.deleteDirectory(contextDir)

        scheduleRepository.delete(schedule)
    }

    fun tagFriend(loginMember: LoginMember, scheduleId: UUID, friendId: Long) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val friend = memberRepository.findById(friendId).orElseThrow()
        val login = memberRepository.findById(loginMember.id).orElseThrow()

        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        if (!friendService.isFriend(login, friend)) {
            throw AuthException("$friend is not friend of $loginMember")
        }

        schedule.addTag(friend)
        eventPublisher.publishEvent(
            ScheduleTaggedEvent(
                scheduleId = schedule.id,
                ownerId = schedule.member.id!!,
                taggedMemberId = friend.id!!,
                scheduleTitle = schedule.content
            )
        )
    }

    fun untagFriend(loginMember: LoginMember, scheduleId: UUID, memberId: Long) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val member = memberRepository.findById(memberId).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        schedule.removeTag(member)
    }

    fun untagSelf(loginMember: LoginMember, scheduleId: UUID) {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        schedule.removeTag(member)
    }

}
