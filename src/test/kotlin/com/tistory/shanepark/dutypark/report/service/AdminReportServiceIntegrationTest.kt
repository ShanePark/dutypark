package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.attachment.service.StoragePathResolver
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.member.domain.enums.MemberStatus
import com.tistory.shanepark.dutypark.report.domain.dto.UpdateReportStatusRequest
import com.tistory.shanepark.dutypark.report.domain.entity.ContentReport
import com.tistory.shanepark.dutypark.report.domain.enums.ReportReason
import com.tistory.shanepark.dutypark.report.domain.enums.ReportStatus
import com.tistory.shanepark.dutypark.report.domain.enums.ReportTargetType
import com.tistory.shanepark.dutypark.report.repository.ContentReportRepository
import com.tistory.shanepark.dutypark.schedule.domain.entity.Schedule
import com.tistory.shanepark.dutypark.schedule.repository.ScheduleRepository
import com.tistory.shanepark.dutypark.todo.domain.entity.Todo
import com.tistory.shanepark.dutypark.todo.repository.TodoRepository
import org.assertj.core.api.Assertions.assertThat
import org.junit.jupiter.api.Test
import org.junit.jupiter.api.assertThrows
import org.springframework.beans.factory.annotation.Autowired
import org.springframework.data.domain.PageRequest
import java.nio.file.Files
import java.time.LocalDateTime
import java.util.*

class AdminReportServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var adminReportService: AdminReportService

    @Autowired
    lateinit var contentReportRepository: ContentReportRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var todoRepository: TodoRepository

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Autowired
    lateinit var pathResolver: StoragePathResolver

    @Test
    fun `find reports returns newest first`() {
        val older = saveReport(reason = ReportReason.SPAM)
        val newer = saveReport(reason = ReportReason.HARASSMENT)
        flushAndClear()

        val page = adminReportService.findReports(status = null, pageable = PageRequest.of(0, 10))

        assertThat(page.content.map { it.id }).containsExactly(newer.id, older.id)
        assertThat(page.content.first().reason).isEqualTo(ReportReason.HARASSMENT)
    }

    @Test
    fun `find reports filters by status`() {
        val open = saveReport()
        val resolved = saveReport(status = ReportStatus.RESOLVED)
        val dismissed = saveReport(status = ReportStatus.DISMISSED)
        flushAndClear()

        assertThat(findIds(ReportStatus.OPEN)).containsExactly(open.id)
        assertThat(findIds(ReportStatus.RESOLVED)).containsExactly(resolved.id)
        assertThat(findIds(ReportStatus.DISMISSED)).containsExactly(dismissed.id)
        assertThat(findIds(null)).containsExactlyInAnyOrder(open.id, resolved.id, dismissed.id)
    }

    @Test
    fun `find reports paginates`() {
        repeat(3) { saveReport() }
        flushAndClear()

        val firstPage = adminReportService.findReports(status = null, pageable = PageRequest.of(0, 2))
        val secondPage = adminReportService.findReports(status = null, pageable = PageRequest.of(1, 2))

        assertThat(firstPage.content).hasSize(2)
        assertThat(firstPage.totalElements).isEqualTo(3)
        assertThat(secondPage.content).hasSize(1)
        assertThat(secondPage.content.map { it.id }).doesNotContainAnyElementsOf(firstPage.content.map { it.id })
    }

    @Test
    fun `summary carries both parties and a snapshot preview`() {
        saveReport(contentSnapshot = "제목: ${"가".repeat(150)}\n내용: 본문")
        flushAndClear()

        val summary = adminReportService.findReports(status = null, pageable = PageRequest.of(0, 10)).content.single()

        assertThat(summary.reporter?.id).isEqualTo(TestData.member.id)
        assertThat(summary.reporter?.status).isEqualTo(MemberStatus.ACTIVE)
        assertThat(summary.reportedMember?.name).isEqualTo(TestData.member2.name)
        assertThat(summary.snapshotPreview).isEqualTo("제목: ${"가".repeat(96)}")
        assertThat(summary.snapshotPreview).hasSize(100)
    }

    @Test
    fun `find report detail exposes snapshot and target existence`() {
        val schedule = saveSchedule(TestData.member2)
        val report = saveReport(
            targetType = ReportTargetType.SCHEDULE,
            targetId = schedule.id.toString(),
            detail = "부적절한 표현",
            contentSnapshot = "제목: 회식\n내용: 설명\n첨부: 없음",
        )
        flushAndClear()

        val detail = adminReportService.findReport(report.id)

        assertThat(detail.detail).isEqualTo("부적절한 표현")
        assertThat(detail.contentSnapshot).isEqualTo("제목: 회식\n내용: 설명\n첨부: 없음")
        assertThat(detail.targetExists).isTrue()
        assertThat(detail.resolvedAt).isNull()
        assertThat(detail.resolvedByName).isNull()
    }

    @Test
    fun `find report detail reports a missing target as gone`() {
        val report = saveReport(
            targetType = ReportTargetType.SCHEDULE,
            targetId = UUID.randomUUID().toString(),
        )
        flushAndClear()

        assertThat(adminReportService.findReport(report.id).targetExists).isFalse()
    }

    @Test
    fun `find report detail keeps snapshot names after the members are deleted`() {
        val reporter = memberRepository.save(Member("reporter", "reporter@duty.park", "pass"))
        val reported = memberRepository.save(Member("reported", "reported@duty.park", "pass"))
        flushAndClear()
        val report = saveReport(reporter = reporter, reported = reported)
        flushAndClear()

        em.createNativeQuery("delete from member where id in (:ids)")
            .setParameter("ids", listOf(reporter.id!!, reported.id!!))
            .executeUpdate()
        flushAndClear()

        val detail = adminReportService.findReport(report.id)

        assertThat(detail.reporter).isNull()
        assertThat(detail.reportedMember).isNull()
        assertThat(detail.reporterName).isEqualTo("reporter")
        assertThat(detail.reportedMemberName).isEqualTo("reported")
    }

    @Test
    fun `find report detail of an unknown report throws`() {
        assertThrows<NoSuchElementException> {
            adminReportService.findReport(UUID.randomUUID())
        }
    }

    @Test
    fun `update status records the resolver and the memo`() {
        val report = saveReport()
        flushAndClear()

        val detail = adminReportService.updateStatus(
            reportId = report.id,
            adminMemberId = TestData.admin.id!!,
            request = UpdateReportStatusRequest(status = ReportStatus.RESOLVED, memo = "콘텐츠 삭제 완료"),
        )
        flushAndClear()

        assertThat(detail.status).isEqualTo(ReportStatus.RESOLVED)
        assertThat(detail.adminMemo).isEqualTo("콘텐츠 삭제 완료")
        assertThat(detail.resolvedByName).isEqualTo(TestData.admin.name)
        assertThat(detail.resolvedAt).isNotNull()

        val saved = contentReportRepository.findById(report.id).orElseThrow()
        assertThat(saved.status).isEqualTo(ReportStatus.RESOLVED)
        assertThat(saved.adminMemo).isEqualTo("콘텐츠 삭제 완료")
        assertThat(saved.resolvedBy).isEqualTo(TestData.admin.id)
        assertThat(saved.resolvedAt).isNotNull()
    }

    @Test
    fun `update status to dismissed is allowed`() {
        val report = saveReport()
        flushAndClear()

        val detail = adminReportService.updateStatus(
            reportId = report.id,
            adminMemberId = TestData.admin.id!!,
            request = UpdateReportStatusRequest(status = ReportStatus.DISMISSED, memo = null),
        )

        assertThat(detail.status).isEqualTo(ReportStatus.DISMISSED)
        assertThat(detail.adminMemo).isNull()
    }

    @Test
    fun `update status back to open is rejected`() {
        val report = saveReport()
        flushAndClear()

        assertThrows<BadRequestException> {
            adminReportService.updateStatus(
                reportId = report.id,
                adminMemberId = TestData.admin.id!!,
                request = UpdateReportStatusRequest(status = ReportStatus.OPEN, memo = null),
            )
        }
    }

    @Test
    fun `delete target removes the schedule with its attachments and context directory`() {
        val schedule = saveSchedule(TestData.member2)
        val contextId = schedule.id.toString()
        saveAttachment(AttachmentContextType.SCHEDULE, contextId)
        val contextDir = pathResolver.resolveContextDirectory(AttachmentContextType.SCHEDULE, contextId)
        Files.createDirectories(contextDir)
        Files.createFile(contextDir.resolve("stored-photo.png"))
        val report = saveReport(targetType = ReportTargetType.SCHEDULE, targetId = contextId)
        flushAndClear()

        val detail = adminReportService.deleteTarget(report.id)
        flushAndClear()

        assertThat(detail.targetExists).isFalse()
        assertThat(scheduleRepository.findById(schedule.id)).isEmpty
        assertThat(attachmentRepository.findAllByContextTypeAndContextId(AttachmentContextType.SCHEDULE, contextId))
            .isEmpty()
        assertThat(Files.exists(contextDir)).isFalse()
    }

    @Test
    fun `delete target removes the todo with its attachments`() {
        val todo = saveTodo(TestData.member2)
        val contextId = todo.id.toString()
        saveAttachment(AttachmentContextType.TODO, contextId)
        val report = saveReport(targetType = ReportTargetType.TODO, targetId = contextId)
        flushAndClear()

        val detail = adminReportService.deleteTarget(report.id)
        flushAndClear()

        assertThat(detail.targetExists).isFalse()
        assertThat(todoRepository.findById(todo.id)).isEmpty
        assertThat(attachmentRepository.findAllByContextTypeAndContextId(AttachmentContextType.TODO, contextId))
            .isEmpty()
    }

    @Test
    fun `delete target keeps the report itself`() {
        val schedule = saveSchedule(TestData.member2)
        val report = saveReport(targetType = ReportTargetType.SCHEDULE, targetId = schedule.id.toString())
        flushAndClear()

        adminReportService.deleteTarget(report.id)
        flushAndClear()

        assertThat(contentReportRepository.findById(report.id)).isPresent
    }

    @Test
    fun `delete target of a member report is rejected`() {
        val report = saveReport()
        flushAndClear()

        val exception = assertThrows<BadRequestException> {
            adminReportService.deleteTarget(report.id)
        }
        assertThat(exception.message).isEqualTo("report.target.notDeletable")
    }

    @Test
    fun `delete target is idempotent when the content is already gone`() {
        val report = saveReport(
            targetType = ReportTargetType.TODO,
            targetId = UUID.randomUUID().toString(),
        )
        flushAndClear()

        val detail = adminReportService.deleteTarget(report.id)

        assertThat(detail.targetExists).isFalse()
    }

    @Test
    fun `delete target of a malformed target id is idempotent`() {
        val report = saveReport(
            targetType = ReportTargetType.SCHEDULE,
            targetId = "not-a-uuid",
        )
        flushAndClear()

        assertThat(adminReportService.deleteTarget(report.id).targetExists).isFalse()
    }

    private fun findIds(status: ReportStatus?) =
        adminReportService.findReports(status = status, pageable = PageRequest.of(0, 10)).content.map { it.id }

    private fun saveReport(
        reporter: Member = TestData.member,
        reported: Member = TestData.member2,
        targetType: ReportTargetType = ReportTargetType.MEMBER,
        targetId: String = reported.id!!.toString(),
        reason: ReportReason = ReportReason.SPAM,
        detail: String? = null,
        contentSnapshot: String = "이름: ${reported.name}\n프로필 사진: 없음(version 0)",
        status: ReportStatus = ReportStatus.OPEN,
    ): ContentReport {
        val report = ContentReport(
            reporter = reload(reporter),
            reportedMember = reload(reported),
            targetType = targetType,
            targetId = targetId,
            reason = reason,
            detail = detail,
            contentSnapshot = contentSnapshot,
            reporterName = reporter.name,
            reportedMemberName = reported.name,
        )
        report.status = status
        return contentReportRepository.save(report)
    }

    private fun saveSchedule(member: Member): Schedule {
        return scheduleRepository.save(
            Schedule(
                member = reload(member),
                content = "회식",
                description = "설명",
                startDateTime = LocalDateTime.of(2026, 8, 18, 10, 0),
                endDateTime = LocalDateTime.of(2026, 8, 18, 11, 0),
            )
        )
    }

    private fun saveTodo(member: Member): Todo {
        return todoRepository.save(
            Todo(
                member = reload(member),
                title = "할 일",
                content = "내용",
                position = 0,
            )
        )
    }

    private fun saveAttachment(contextType: AttachmentContextType, contextId: String) {
        attachmentRepository.save(
            Attachment(
                contextType = contextType,
                contextId = contextId,
                originalFilename = "photo.png",
                storedFilename = "stored-photo.png",
                contentType = "image/png",
                size = 100,
                storagePath = "/tmp/photo.png",
                orderIndex = 0,
                createdBy = TestData.member2.id!!,
            )
        )
    }

    private fun reload(member: Member): Member = memberRepository.findById(member.id!!).orElseThrow()

    private fun flushAndClear() {
        em.flush()
        em.clear()
    }

}
