package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.common.config.logger
import com.tistory.shanepark.dutypark.common.logging.auditEventAfterCommit
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType.SCHEDULE
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import com.tistory.shanepark.dutypark.attachment.service.FileSystemService
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.domain.dto.CalendarView
import com.tistory.shanepark.dutypark.common.exceptions.ForbiddenException
import com.tistory.shanepark.dutypark.common.logging.AuditActor
import com.tistory.shanepark.dutypark.common.logging.toAuditActor
import com.tistory.shanepark.dutypark.consent.service.AiScheduleParsingConsentService
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.repository.MemberRepository
import com.tistory.shanepark.dutypark.member.service.FriendService
import com.tistory.shanepark.dutypark.notification.event.ScheduleTaggedEvent
import com.tistory.shanepark.dutypark.member.domain.dto.MemberPreviewDto
import com.tistory.shanepark.dutypark.member.domain.dto.toMemberPreviewDto
import com.tistory.shanepark.dutypark.schedule.event.ScheduleUpdatedEvent
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleDto
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.SKIP
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus.WAIT
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.timeparsing.service.ScheduleTimeParsingQueueManager
import com.tistory.shanepark.dutypark.security.domain.dto.LoginMember
import org.springframework.context.ApplicationEventPublisher
import org.springframework.stereotype.Service
import org.springframework.transaction.annotation.Transactional
import java.time.LocalDateTime
import java.util.*

data class ScheduleCreationResult(val schedule: Schedule, val created: Boolean)

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
    private val aiScheduleParsingConsentService: AiScheduleParsingConsentService,
    private val revisionService: ScheduleRevisionService,
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

        val userScheduleEntities = scheduleRepository.findSchedulesOfMemberRangeIn(
            member, start, end, visibilities = availableVisibilities,
        )
        val taggedScheduleEntities = scheduleRepository.findTaggedSchedulesOfRange(
            member, start, end, visibilities = availableVisibilities,
        )
        val allScheduleDtos = userScheduleEntities.flatMap { ScheduleDto.of(calendarView, it, isTagged = false) } +
            taggedScheduleEntities.flatMap { ScheduleDto.of(calendarView, it, isTagged = true) }
        val sourceSchedules = (userScheduleEntities + taggedScheduleEntities).associateBy { it.id }
        val editableOwners = sourceSchedules.values.map { it.member }.distinctBy { it.id }
            .associate { it.id to schedulePermissionService.canWrite(loginMember, it) }
        val actorIds = sourceSchedules.values.flatMap { listOfNotNull(it.createdById, it.lastEditedById) }.distinct()
        val actors = memberRepository.findAllById(actorIds).associateBy { it.id }
        val delegatedIds = if (loginMember == null) emptySet() else revisionService.delegatedScheduleIds(sourceSchedules.keys)
        val metadata = sourceSchedules.mapValues { (_, schedule) ->
            val creator = actorPreview(schedule.createdById, schedule.createdByName, actors)
            val editor = actorPreview(schedule.lastEditedById, schedule.lastEditedByName, actors)
            Triple(creator, editor, loginMember != null && (schedule.member.id != loginMember.id || schedule.id in delegatedIds))
        }

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
                val info = metadata[dto.id]
                dto.copy(attachments = attachments, canEdit = editableOwners[dto.ownerMemberId] == true,
                    canReport = info?.third == true, canBlockWithReport = dto.id !in delegatedIds,
                    createdBy = info?.first, lastEditedBy = info?.second)
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

    private fun actorPreview(id: Long?, name: String?, actors: Map<Long?, Member>): MemberPreviewDto? {
        if (id == null && name == null) return null
        return actors[id]?.toMemberPreviewDto() ?: MemberPreviewDto(id = id, name = name ?: "")
    }

    @Transactional(readOnly = true)
    fun getScheduleBasicInfo(loginMember: LoginMember?, scheduleId: UUID): Map<String, Any?> {
        val schedule = scheduleRepository.findById(scheduleId).orElseThrow()
        val isTagged = loginMember != null && schedule.tags.any { it.member.id == loginMember.id }
        if (!isTagged) {
            schedulePermissionService.checkScheduleReadAuthority(loginMember, schedule)
        }
        val owner = schedule.member

        return mapOf(
            "id" to schedule.id.toString(),
            "memberId" to owner.id!!,
            "memberName" to owner.name,
            "startDateTime" to schedule.startDateTime.toString(),
            "content" to schedule.content,
            "ownerMemberId" to owner.id,
            "canEdit" to schedulePermissionService.canWrite(loginMember, owner),
            "canReport" to (loginMember != null && revisionService.canReport(schedule, loginMember.id)),
            "canBlockWithReport" to revisionService.canBlockWithReport(schedule),
            "version" to schedule.version,
            "lastEditedAt" to schedule.lastEditedAt,
            "lastEditedBy" to actorPreview(schedule.lastEditedById, schedule.lastEditedByName,
                memberRepository.findAllById(listOfNotNull(schedule.lastEditedById)).associateBy { it.id }),
            "createdBy" to actorPreview(schedule.createdById, schedule.createdByName,
                memberRepository.findAllById(listOfNotNull(schedule.createdById)).associateBy { it.id }),
        )
    }

    fun createSchedule(
        loginMember: LoginMember,
        scheduleSaveDto: ScheduleSaveDto,
    ): ScheduleCreationResult {
        val scheduleMember = memberRepository.findById(scheduleSaveDto.memberId).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(loginMember, scheduleMember)

        // Duplicate detection and creation must share the owner lock. Without
        // it, two devices can both observe no matching schedule and create two
        // rows before either transaction commits.
        val lockedScheduleMember = memberRepository
            .findMemberWithTeamForUpdate(scheduleMember.id!!)
            .orElseThrow { IllegalStateException("Member not found") }
        scheduleRepository
            .findFirstByMemberIdAndContentAndDescriptionAndStartDateTimeAndEndDateTimeOrderByCreatedDateAscIdAsc(
                memberId = lockedScheduleMember.id!!,
                content = scheduleSaveDto.content,
                description = scheduleSaveDto.description,
                startDateTime = scheduleSaveDto.startDateTime,
                endDateTime = scheduleSaveDto.endDateTime,
            )
            .orElse(null)
            ?.let { return ScheduleCreationResult(it, created = false) }

        val startDateTime = scheduleSaveDto.startDateTime
        val position = findNextPosition(lockedScheduleMember, startDateTime)
        val schedule = Schedule(
            member = lockedScheduleMember,
            content = scheduleSaveDto.content,
            description = scheduleSaveDto.description,
            startDateTime = startDateTime,
            endDateTime = scheduleSaveDto.endDateTime,
            position = position,
            visibility = scheduleSaveDto.visibility
        )

        schedule.createdById = loginMember.id
        schedule.createdByName = loginMember.name
        applyAiParsingPreference(schedule, scheduleSaveDto.aiTimeParsingRequested)
        scheduleRepository.save(schedule)
        syncScheduleTags(schedule, scheduleSaveDto.tagFriendIds.orEmpty(), loginMember)
        if (schedule.parsingTimeStatus == WAIT) {
            scheduleTimeParsingQueueManager.addTask(schedule)
        }

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = SCHEDULE,
            contextId = schedule.id.toString(),
            attachmentSessionId = scheduleSaveDto.attachmentSessionId,
            orderedAttachmentIds = scheduleSaveDto.orderedAttachmentIds
        )

        revisionService.recordCreation(schedule, loginMember)

        log.auditEventAfterCommit("schedule.created", loginMember.toAuditActor(), scheduleAuditTarget(schedule),
            mapOf("visibility" to schedule.visibility.name, "parsingStatus" to schedule.parsingTimeStatus.name,
                "attachmentCount" to scheduleSaveDto.orderedAttachmentIds.size,
                "startDateTime" to schedule.startDateTime, "endDateTime" to schedule.endDateTime))
        return ScheduleCreationResult(schedule, created = true)
    }

    private fun scheduleAuditTarget(schedule: Schedule) = mapOf(
        "scheduleId" to schedule.id, "memberId" to schedule.member.id,
    )

    private fun findNextPosition(
        member: Member,
        startDateTime: LocalDateTime
    ) = scheduleRepository.findMaxPosition(member, startDateTime) + 1

    fun updateSchedule(loginMember: LoginMember, scheduleSaveDto: ScheduleSaveDto): Schedule {
        if (scheduleSaveDto.id == null)
            throw IllegalArgumentException("Schedule id must not be null to update")

        val schedule = scheduleRepository.findByIdForUpdate(scheduleSaveDto.id).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        if (scheduleSaveDto.expectedVersion != null && scheduleSaveDto.expectedVersion != schedule.version) {
            throw ScheduleVersionConflictException()
        }
        val before = revisionService.capture(schedule)
        val changedFields = mutableListOf<String>()
        if (schedule.content() != scheduleSaveDto.content) changedFields.add("content")
        if (schedule.description != scheduleSaveDto.description) changedFields.add("description")
        if (schedule.startDateTime != scheduleSaveDto.startDateTime) changedFields.add("startDateTime")
        if (schedule.endDateTime != scheduleSaveDto.endDateTime) changedFields.add("endDateTime")
        val previousStart = schedule.startDateTime
        val previousEnd = schedule.endDateTime
        val previousVisibility = schedule.visibility
        val previousParsingStatus = schedule.parsingTimeStatus
        val parsingInputChanged = schedule.updateParsingInput(
            content = scheduleSaveDto.content,
            startDateTime = scheduleSaveDto.startDateTime,
            endDateTime = scheduleSaveDto.endDateTime,
        )
        schedule.description = scheduleSaveDto.description
        schedule.visibility = scheduleSaveDto.visibility
        scheduleSaveDto.tagFriendIds?.let { if (syncScheduleTags(schedule, it, loginMember)) changedFields.add("tags") }

        if (
            parsingInputChanged ||
            schedule.parsingTimeStatus == WAIT
        ) {
            applyAiParsingPreference(schedule, scheduleSaveDto.aiTimeParsingRequested)
        }
        scheduleRepository.save(schedule)
        if (parsingInputChanged && schedule.parsingTimeStatus == WAIT) {
            scheduleTimeParsingQueueManager.addTask(schedule)
        }

        val scheduleId = schedule.id.toString()
        val orderedIds = scheduleSaveDto.orderedAttachmentIds

        attachmentService.synchronizeContextAttachments(
            loginMember = loginMember,
            contextType = SCHEDULE,
            contextId = scheduleId,
            attachmentSessionId = scheduleSaveDto.attachmentSessionId,
            orderedAttachmentIds = orderedIds
        )

        val after = revisionService.recordChange(schedule, before, loginMember)
        if (before.hasNotifiableChanges(after)) {
            eventPublisher.publishEvent(ScheduleUpdatedEvent(schedule.id, schedule.member.id!!, loginMember.id, schedule.version, before, after))
        }

        if (previousVisibility != schedule.visibility) changedFields.add("visibility")
        if (previousParsingStatus != schedule.parsingTimeStatus) changedFields.add("parsingStatus")
        if (changedFields.isNotEmpty()) {
            log.auditEventAfterCommit("schedule.updated", loginMember.toAuditActor(), scheduleAuditTarget(schedule),
                mapOf("changedFields" to changedFields, "visibilityBefore" to previousVisibility.name,
                    "visibilityAfter" to schedule.visibility.name,
                    "startDateTimeBefore" to previousStart, "startDateTimeAfter" to schedule.startDateTime,
                    "endDateTimeBefore" to previousEnd, "endDateTimeAfter" to schedule.endDateTime,
                    "parsingStatusBefore" to previousParsingStatus.name, "parsingStatusAfter" to schedule.parsingTimeStatus.name))
        }
        return schedule
    }

    private fun applyAiParsingPreference(schedule: Schedule, aiTimeParsingRequested: Boolean) {
        if (!aiTimeParsingRequested || !aiScheduleParsingConsentService.hasCurrentConsent(schedule.member.id!!)) {
            schedule.parsingTimeStatus = SKIP
        }
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

        val positionChanges = mutableListOf<Map<String, Any?>>()
        scheduleIds.forEachIndexed { index, scheduleId ->
            val schedule = schedules.find { it.id == scheduleId }!!
            if (schedule.position != index) {
                positionChanges.add(mapOf("scheduleId" to scheduleId, "before" to schedule.position, "after" to index))
            }
            schedule.position = index
        }
        if (positionChanges.isNotEmpty()) {
            log.auditEventAfterCommit("schedule.reordered", loginMember.toAuditActor(),
                details = mapOf("scheduleCount" to scheduleIds.size, "positionChanges" to positionChanges))
        }
    }

    fun deleteSchedule(loginMember: LoginMember, id: UUID) {
        val schedule = scheduleRepository.findByIdForUpdate(id).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        deleteScheduleInternal(schedule, actor = loginMember.toAuditActor())
    }

    /**
     * Deletes a schedule with its attachments and context directory, without any permission check.
     * Callers are responsible for authorization (admin moderation calls this directly).
     */
    internal fun deleteScheduleInternal(schedule: Schedule, actor: AuditActor? = null) {
        val contextId = schedule.id.toString()
        val attachments = attachmentRepository.findAllByContextTypeAndContextId(SCHEDULE, contextId)

        attachments.forEach { attachment ->
            attachmentService.deleteAttachment(attachment, actor = actor, reason = "schedule_deleted")
        }

        val contextDir = pathResolver.resolveContextDirectory(SCHEDULE, contextId)
        fileSystemService.deleteDirectory(contextDir)

        revisionService.deleteAll(schedule)
        scheduleRepository.delete(schedule)
        log.auditEventAfterCommit("schedule.deleted", actor, scheduleAuditTarget(schedule),
            mapOf("attachmentCount" to attachments.size))
    }

    fun tagFriend(loginMember: LoginMember, scheduleId: UUID, friendId: Long) {
        val schedule = scheduleRepository.findByIdForUpdate(scheduleId).orElseThrow()
        val before = revisionService.capture(schedule)
        val friend = memberRepository.findById(friendId).orElseThrow()

        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)
        addTagToSchedule(schedule, friend, loginMember)
        revisionService.recordChange(schedule, before, loginMember)
        log.auditEventAfterCommit("schedule.tag_added", loginMember.toAuditActor(), scheduleAuditTarget(schedule),
            mapOf("taggedMemberId" to friendId))
    }

    fun untagFriend(loginMember: LoginMember, scheduleId: UUID, memberId: Long) {
        val schedule = scheduleRepository.findByIdForUpdate(scheduleId).orElseThrow()
        val before = revisionService.capture(schedule)
        val member = memberRepository.findById(memberId).orElseThrow()
        schedulePermissionService.checkScheduleWriteAuthority(schedule = schedule, loginMember = loginMember)

        schedule.removeTag(member)
        revisionService.recordChange(schedule, before, loginMember)
        log.auditEventAfterCommit("schedule.tag_removed", loginMember.toAuditActor(), scheduleAuditTarget(schedule),
            mapOf("taggedMemberId" to member.id))
    }

    fun untagSelf(loginMember: LoginMember, scheduleId: UUID) {
        val schedule = scheduleRepository.findByIdForUpdate(scheduleId).orElseThrow()
        val before = revisionService.capture(schedule)
        val member = memberRepository.findById(loginMember.id).orElseThrow()
        schedule.removeTag(member)
        revisionService.recordChange(schedule, before, loginMember, "PARTICIPATION")
        log.auditEventAfterCommit("schedule.tag_removed", loginMember.toAuditActor(), scheduleAuditTarget(schedule),
            mapOf("taggedMemberId" to member.id))
    }

    private fun syncScheduleTags(schedule: Schedule, tagFriendIds: List<Long>, actor: LoginMember): Boolean {
        val desiredTagIds = tagFriendIds.distinct()
        val desiredTagSet = desiredTagIds.toSet()

        val removedTagIds = schedule.tags
            .mapNotNull { it.member.id }
            .filterNot(desiredTagSet::contains)
        removedTagIds.forEach { memberId ->
            val member = memberRepository.findById(memberId).orElseThrow()
            schedule.removeTag(member)
        }

        val existingTagIds = schedule.tags.mapNotNull { it.member.id }.toSet()
        val addedTagIds = desiredTagIds.filterNot(existingTagIds::contains)
        addedTagIds.forEach { friendId ->
            val friend = memberRepository.findById(friendId).orElseThrow()
            addTagToSchedule(schedule, friend, actor)
        }
        return removedTagIds.isNotEmpty() || addedTagIds.isNotEmpty()
    }

    private fun addTagToSchedule(schedule: Schedule, friend: Member, actor: LoginMember) {
        if (!friendService.isFriend(schedule.member, friend)) {
            throw ForbiddenException("schedule.tag.notFriend")
        }

        schedule.addTag(friend)
        publishScheduleTaggedEvent(schedule, friend, actor)
    }

    private fun publishScheduleTaggedEvent(schedule: Schedule, friend: Member, actor: LoginMember) {
        eventPublisher.publishEvent(
            ScheduleTaggedEvent(
                scheduleId = schedule.id,
                ownerId = schedule.member.id!!,
                actorId = actor.id,
                taggedMemberId = friend.id!!,
                scheduleTitle = schedule.content
            )
        )
    }

}
