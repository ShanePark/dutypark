package com.tistory.shanepark.dutypark.schedule.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.schedule.domain.dto.ScheduleSaveDto
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.domain.enums.ParsingTimeStatus
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRevisionRepository
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.dto.ReorderAttachmentsRequest
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.AttachmentService
import org.junit.jupiter.api.assertThrows
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.springframework.beans.factory.annotation.Autowired
import java.time.LocalDateTime

class ScheduleRevisionIntegrationTest : DutyparkIntegrationTest() {
    @Autowired
    lateinit var scheduleService: ScheduleService

    @Autowired
    lateinit var revisions: ScheduleRevisionRepository
    @Autowired
    lateinit var schedules: ScheduleRepository
    @Autowired
    lateinit var revisionService: ScheduleRevisionService
    @Autowired
    lateinit var parsingResults: ScheduleParsingResultService
    @Autowired
    lateinit var attachments: AttachmentRepository
    @Autowired
    lateinit var attachmentService: AttachmentService

    @Test
    fun `saving an actual edit exposes its version and actual editor`() {
        val owner = TestData.member
        val start = LocalDateTime.of(2026, 11, 23, 14, 0)
        val initial = ScheduleSaveDto(
            memberId = owner.id!!, content = "Meeting", description = "Initial",
            startDateTime = start, endDateTime = start.plusHours(1), aiTimeParsingRequested = false,
        )
        val schedule = scheduleService.createSchedule(loginMember(owner), initial).schedule
        scheduleService.updateSchedule(loginMember(owner), initial.copy(id = schedule.id, description = "Updated"))
        val dto = scheduleService.findSchedulesByYearAndMonth(loginMember(owner), owner.id!!, 2026, 11)
            .flatMap { it }.single { it.id == schedule.id }
        val json = objectMapper.readTree(objectMapper.writeValueAsString(dto))

        assertThat(json.path("version").asLong()).isEqualTo(2)
        assertThat(json.path("ownerMemberId").asLong()).isEqualTo(owner.id)
        assertThat(json.path("canEdit").asBoolean()).isTrue()
        assertThat(json.path("lastEditedBy").path("id").asLong()).isEqualTo(owner.id)
    }

    @Test
    fun `unchanged save keeps version and does not invent an editor`() {
        val request = request()
        val schedule = scheduleService.createSchedule(loginMember(TestData.member), request).schedule
        scheduleService.updateSchedule(loginMember(TestData.member), request.copy(id = schedule.id, expectedVersion = 1))
        assertThat(schedule.version).isEqualTo(1)
        assertThat(schedule.lastEditedById).isNull()
        assertThat(revisions.findAllByScheduleIdOrderByVersionAsc(schedule.id)).hasSize(1)
    }

    @Test
    fun `manager edits tagged schedule in own calendar and records actual actor`() {
        val owner = TestData.member
        val manager = TestData.member2
        makeThemFriend(owner, manager)
        makeManagerRelation(manager, owner)
        val request = request().copy(tagFriendIds = listOf(manager.id!!))
        val schedule = scheduleService.createSchedule(loginMember(owner), request).schedule
        val dto = scheduleService.findSchedulesByYearAndMonth(loginMember(manager), manager.id!!, 2026, 11)
            .flatMap { it }.single { it.id == schedule.id }
        assertThat(dto.canEdit).isTrue()
        scheduleService.updateSchedule(loginMember(manager), request.copy(id = schedule.id, content = "Edited", expectedVersion = dto.version))
        assertThat(schedule.member.id).isEqualTo(owner.id)
        assertThat(schedule.createdById).isEqualTo(owner.id)
        assertThat(schedule.lastEditedById).isEqualTo(manager.id)
        val history = revisions.findAllByScheduleIdOrderByVersionAsc(schedule.id)
        assertThat(history.map { it.version }).containsExactly(1L, 2L)
        assertThat(history.last().actorId).isEqualTo(manager.id)
        assertThat(revisionService.snapshot(history.first()).content).isEqualTo("Meeting")
        assertThat(revisionService.snapshot(history.last()).content).isEqualTo("Edited")
        val ownerDto = scheduleService.findSchedulesByYearAndMonth(loginMember(owner), owner.id!!, 2026, 11)
            .flatMap { it }.single { it.id == schedule.id }
        assertThat(ownerDto.canReport).isTrue()
        assertThat(ownerDto.canBlockWithReport).isFalse()
    }

    @Test
    fun `stale version fails before content and history are changed`() {
        val request = request()
        val schedule = scheduleService.createSchedule(loginMember(TestData.member), request).schedule
        val error = assertThrows<ScheduleVersionConflictException> {
            scheduleService.updateSchedule(loginMember(TestData.member), request.copy(id = schedule.id, content = "Stale", expectedVersion = 0))
        }
        assertThat(error.errorCode).isEqualTo(409)
        assertThat(schedule.content).isEqualTo("Meeting")
        assertThat(revisions.findAllByScheduleIdOrderByVersionAsc(schedule.id)).hasSize(1)
    }

    @Test
    fun `first legacy edit saves the original baseline without guessing its author`() {
        val request = request()
        val legacy = schedules.save(Schedule(TestData.member, request.content, request.description,
            request.startDateTime, request.endDateTime, parsingTimeStatus = ParsingTimeStatus.SKIP))
        scheduleService.updateSchedule(loginMember(TestData.member), request.copy(id = legacy.id, description = "Updated", expectedVersion = 0))
        val history = revisions.findAllByScheduleIdOrderByVersionAsc(legacy.id)
        assertThat(history.map { it.version }).containsExactly(0L, 1L)
        assertThat(history.first().actorId).isNull()
        assertThat(history.first().source).isEqualTo("BASELINE")
        assertThat(revisionService.snapshot(history.first()).description).isEqualTo("Initial")
        assertThat(legacy.createdById).isNull()
    }

    @Test
    fun `AI time result creates system revision while retaining human editor`() {
        val request = request()
        val schedule = scheduleService.createSchedule(loginMember(TestData.member), request).schedule
        scheduleService.updateSchedule(loginMember(TestData.member), request.copy(id = schedule.id, description = "Human edit"))
        val editedAt = schedule.lastEditedAt
        schedule.parsingTimeStatus = ParsingTimeStatus.WAIT
        assertThat(parsingResults.applyParsingResultIfCurrent(schedule.id, schedule.parsingGeneration,
            ParsingTimeStatus.WAIT, ParsingTimeStatus.PARSED, request.startDateTime.plusHours(1),
            request.endDateTime.plusHours(1), "Parsed title")).isEqualTo(1)
        assertThat(schedule.version).isEqualTo(3)
        assertThat(schedule.lastEditedById).isEqualTo(TestData.member.id)
        assertThat(schedule.lastEditedAt).isEqualTo(editedAt)
        assertThat(revisions.findAllByScheduleIdOrderByVersionAsc(schedule.id).last().source).isEqualTo("SYSTEM")
    }

    @Test
    fun `direct attachment reorder and deletion each create one revision`() {
        val schedule = scheduleService.createSchedule(loginMember(TestData.member), request()).schedule
        val first = attachments.save(attachment(schedule, "first.txt", 0))
        val second = attachments.save(attachment(schedule, "second.txt", 1))
        attachmentService.reorderAttachments(loginMember(TestData.member), ReorderAttachmentsRequest(
            AttachmentContextType.SCHEDULE, schedule.id.toString(), listOf(second.id, first.id)))
        assertThat(schedule.version).isEqualTo(2)
        val reordered = revisionService.snapshot(revisions.findByScheduleIdAndVersion(schedule.id, 2)!!)
        assertThat(reordered.attachments.map { it.id }).containsExactly(second.id, first.id)
        attachmentService.deleteAttachment(loginMember(TestData.member), first.id)
        assertThat(schedule.version).isEqualTo(3)
        assertThat(revisionService.snapshot(revisions.findByScheduleIdAndVersion(schedule.id, 3)!!).attachments.map { it.id })
            .containsExactly(second.id)
    }

    @Test
    fun `schedule deletion cascades all general revisions`() {
        val schedule = scheduleService.createSchedule(loginMember(TestData.member), request()).schedule
        scheduleService.updateSchedule(loginMember(TestData.member), request().copy(id = schedule.id, description = "Changed"))
        scheduleService.deleteSchedule(loginMember(TestData.member), schedule.id)
        em.flush()
        em.clear()
        assertThat(revisions.findAllByScheduleIdOrderByVersionAsc(schedule.id)).isEmpty()
    }

    @Test
    fun `self untag records participation without replacing the editor or allowing owner report`() {
        val owner = TestData.member
        val participant = TestData.member2
        makeThemFriend(owner, participant)
        val request = request().copy(tagFriendIds = listOf(participant.id!!))
        val schedule = scheduleService.createSchedule(loginMember(owner), request).schedule
        scheduleService.updateSchedule(loginMember(owner), request.copy(id = schedule.id, description = "Owner update"))
        val editedAt = schedule.lastEditedAt
        scheduleService.untagSelf(loginMember(participant), schedule.id)
        assertThat(schedule.version).isEqualTo(3)
        assertThat(schedule.lastEditedById).isEqualTo(owner.id)
        assertThat(schedule.lastEditedAt).isEqualTo(editedAt)
        val revision = revisions.findByScheduleIdAndVersion(schedule.id, 3)!!
        assertThat(revision.source).isEqualTo("PARTICIPATION")
        assertThat(revision.actorId).isEqualTo(participant.id)
        assertThat(revisionService.canReport(schedule, owner.id!!)).isFalse()
        assertThat(revisionService.canBlockWithReport(schedule)).isTrue()
    }

    @Test
    fun `schedule save with attachment reorder produces exactly one new revision`() {
        val request = request()
        val schedule = scheduleService.createSchedule(loginMember(TestData.member), request).schedule
        val first = attachments.save(attachment(schedule, "first.txt", 0))
        val second = attachments.save(attachment(schedule, "second.txt", 1))
        scheduleService.updateSchedule(loginMember(TestData.member), request.copy(id = schedule.id,
            description = "Changed with attachments", orderedAttachmentIds = listOf(second.id, first.id)))
        assertThat(schedule.version).isEqualTo(2)
        val history = revisions.findAllByScheduleIdOrderByVersionAsc(schedule.id)
        assertThat(history.map { it.version }).containsExactly(1L, 2L)
        assertThat(revisionService.snapshot(history.last()).attachments.map { it.id }).containsExactly(second.id, first.id)
    }

    @Test
    fun `tagged participant without management authority cannot edit the original schedule`() {
        val owner = TestData.member
        val participant = TestData.member2
        makeThemFriend(owner, participant)
        val request = request().copy(tagFriendIds = listOf(participant.id!!))
        val schedule = scheduleService.createSchedule(loginMember(owner), request).schedule
        val dto = scheduleService.findSchedulesByYearAndMonth(loginMember(participant), participant.id!!, 2026, 11)
            .flatMap { it }.single { it.id == schedule.id }
        assertThat(dto.canEdit).isFalse()
        assertThrows<com.tistory.shanepark.dutypark.common.exceptions.ForbiddenException> {
            scheduleService.updateSchedule(loginMember(participant), request.copy(id = schedule.id, content = "Unauthorized"))
        }
        assertThat(schedule.version).isEqualTo(1)
    }

    private fun request(): ScheduleSaveDto {
        val start = LocalDateTime.of(2026, 11, 23, 14, 0)
        return ScheduleSaveDto(memberId = TestData.member.id!!, content = "Meeting", description = "Initial",
            startDateTime = start, endDateTime = start.plusHours(1), aiTimeParsingRequested = false)
    }

    private fun attachment(schedule: Schedule, name: String, order: Int) = Attachment(
        contextType = AttachmentContextType.SCHEDULE, contextId = schedule.id.toString(), originalFilename = name,
        storedFilename = name, contentType = "text/plain", size = 1, storagePath = "/tmp/dutypark-test-storage/schedule/" + schedule.id,
        orderIndex = order, createdBy = TestData.member.id!!,
    )

}
