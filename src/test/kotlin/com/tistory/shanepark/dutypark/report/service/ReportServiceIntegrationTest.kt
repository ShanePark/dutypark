package com.tistory.shanepark.dutypark.report.service

import com.tistory.shanepark.dutypark.DutyparkIntegrationTest
import com.tistory.shanepark.dutypark.attachment.domain.entity.Attachment
import com.tistory.shanepark.dutypark.attachment.domain.enums.AttachmentContextType
import com.tistory.shanepark.dutypark.attachment.repository.AttachmentRepository
import com.tistory.shanepark.dutypark.common.exceptions.BadRequestException
import com.tistory.shanepark.dutypark.member.block.repository.MemberBlockRepository
import com.tistory.shanepark.dutypark.member.domain.entity.Member
import com.tistory.shanepark.dutypark.report.domain.dto.CreateReportRequest
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
import java.time.LocalDateTime

class ReportServiceIntegrationTest : DutyparkIntegrationTest() {

    @Autowired
    lateinit var reportService: ReportService

    @Autowired
    lateinit var contentReportRepository: ContentReportRepository

    @Autowired
    lateinit var scheduleRepository: ScheduleRepository

    @Autowired
    lateinit var todoRepository: TodoRepository

    @Autowired
    lateinit var attachmentRepository: AttachmentRepository

    @Autowired
    lateinit var memberBlockRepository: MemberBlockRepository

    @Test
    fun `report member stores member snapshot`() {
        val reporter = TestData.member
        val reported = TestData.member2
        reported.profilePhotoPath = "profile/photo.png"
        reported.profilePhotoVersion = 3
        memberRepository.save(reported)
        flushAndClear()

        val result = reportService.createReport(
            reporter.id!!,
            CreateReportRequest(
                targetType = ReportTargetType.MEMBER,
                targetId = reported.id!!.toString(),
                reason = ReportReason.IMPERSONATION,
                detail = null,
            )
        )
        flushAndClear()

        assertThat(result.isNew).isTrue()
        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.targetType).isEqualTo(ReportTargetType.MEMBER)
        assertThat(report.targetId).isEqualTo(reported.id!!.toString())
        assertThat(report.reason).isEqualTo(ReportReason.IMPERSONATION)
        assertThat(report.status).isEqualTo(ReportStatus.OPEN)
        assertThat(report.reporter?.id).isEqualTo(reporter.id)
        assertThat(report.reportedMember?.id).isEqualTo(reported.id)
        assertThat(report.reporterName).isEqualTo(reporter.name)
        assertThat(report.reportedMemberName).isEqualTo(reported.name)
        assertThat(report.contentSnapshot).isEqualTo("이름: ${reported.name}\n프로필 사진: 있음(version 3)")
    }

    @Test
    fun `report member without profile photo records absence`() {
        val result = reportService.createReport(
            TestData.member.id!!,
            memberReportRequest(TestData.member2),
        )
        flushAndClear()

        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.contentSnapshot)
            .isEqualTo("이름: ${TestData.member2.name}\n프로필 사진: 없음(version 0)")
    }

    @Test
    fun `report schedule stores title description and attachment names`() {
        val schedule = saveSchedule(TestData.member2, content = "회식", description = "장소는 여기")
        saveAttachment(AttachmentContextType.SCHEDULE, schedule.id.toString(), "photo1.png", orderIndex = 0)
        saveAttachment(AttachmentContextType.SCHEDULE, schedule.id.toString(), "photo2.png", orderIndex = 1)
        flushAndClear()

        val result = reportService.createReport(
            TestData.member.id!!,
            CreateReportRequest(
                targetType = ReportTargetType.SCHEDULE,
                targetId = schedule.id.toString(),
                reason = ReportReason.SPAM,
                detail = null,
            )
        )
        flushAndClear()

        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.reportedMember?.id).isEqualTo(TestData.member2.id)
        assertThat(report.reportedMemberName).isEqualTo(TestData.member2.name)
        assertThat(report.contentSnapshot)
            .isEqualTo("제목: 회식\n내용: 장소는 여기\n첨부: photo1.png, photo2.png")
    }

    @Test
    fun `report schedule without attachment records none`() {
        val schedule = saveSchedule(TestData.member2, content = "회식", description = "")
        flushAndClear()

        val result = reportService.createReport(
            TestData.member.id!!,
            CreateReportRequest(
                targetType = ReportTargetType.SCHEDULE,
                targetId = schedule.id.toString(),
                reason = ReportReason.SPAM,
                detail = null,
            )
        )
        flushAndClear()

        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.contentSnapshot).isEqualTo("제목: 회식\n내용: \n첨부: 없음")
    }

    @Test
    fun `schedule description is truncated to 300 characters`() {
        val schedule = saveSchedule(TestData.member2, content = "긴 일정", description = "가".repeat(400))
        flushAndClear()

        val result = reportService.createReport(
            TestData.member.id!!,
            CreateReportRequest(
                targetType = ReportTargetType.SCHEDULE,
                targetId = schedule.id.toString(),
                reason = ReportReason.SPAM,
                detail = null,
            )
        )
        flushAndClear()

        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.contentSnapshot).isEqualTo("제목: 긴 일정\n내용: ${"가".repeat(300)}\n첨부: 없음")
    }

    @Test
    fun `report todo stores title content and attachment names`() {
        val todo = saveTodo(TestData.member2, title = "할 일", content = "설명")
        saveAttachment(AttachmentContextType.TODO, todo.id.toString(), "doc.pdf")
        flushAndClear()

        val result = reportService.createReport(
            TestData.member.id!!,
            CreateReportRequest(
                targetType = ReportTargetType.TODO,
                targetId = todo.id.toString(),
                reason = ReportReason.HARASSMENT,
                detail = "불쾌합니다",
            )
        )
        flushAndClear()

        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.reportedMember?.id).isEqualTo(TestData.member2.id)
        assertThat(report.detail).isEqualTo("불쾌합니다")
        assertThat(report.contentSnapshot).isEqualTo("제목: 할 일\n내용: 설명\n첨부: doc.pdf")
    }

    @Test
    fun `reporting own member profile throws report-self`() {
        val exception = assertThrows<BadRequestException> {
            reportService.createReport(TestData.member.id!!, memberReportRequest(TestData.member))
        }

        assertThat(exception.message).isEqualTo("report.self")
        assertThat(contentReportRepository.findAll()).isEmpty()
    }

    @Test
    fun `reporting own schedule throws report-self`() {
        val schedule = saveSchedule(TestData.member, content = "내 일정", description = "")
        flushAndClear()

        val exception = assertThrows<BadRequestException> {
            reportService.createReport(
                TestData.member.id!!,
                CreateReportRequest(
                    targetType = ReportTargetType.SCHEDULE,
                    targetId = schedule.id.toString(),
                    reason = ReportReason.SPAM,
                    detail = null,
                )
            )
        }

        assertThat(exception.message).isEqualTo("report.self")
    }

    @Test
    fun `reporting own todo throws report-self`() {
        val todo = saveTodo(TestData.member, title = "내 할 일", content = "")
        flushAndClear()

        val exception = assertThrows<BadRequestException> {
            reportService.createReport(
                TestData.member.id!!,
                CreateReportRequest(
                    targetType = ReportTargetType.TODO,
                    targetId = todo.id.toString(),
                    reason = ReportReason.SPAM,
                    detail = null,
                )
            )
        }

        assertThat(exception.message).isEqualTo("report.self")
    }

    @Test
    fun `OTHER reason without detail throws report-detail-required`() {
        val exception = assertThrows<BadRequestException> {
            reportService.createReport(
                TestData.member.id!!,
                memberReportRequest(TestData.member2, reason = ReportReason.OTHER, detail = "  "),
            )
        }

        assertThat(exception.message).isEqualTo("report.detail.required")
        assertThat(contentReportRepository.findAll()).isEmpty()
    }

    @Test
    fun `OTHER reason with detail is accepted`() {
        val result = reportService.createReport(
            TestData.member.id!!,
            memberReportRequest(TestData.member2, reason = ReportReason.OTHER, detail = "기타 사유"),
        )
        flushAndClear()

        assertThat(contentReportRepository.findById(result.id).orElseThrow().detail).isEqualTo("기타 사유")
    }

    @Test
    fun `duplicate open report returns the existing report id`() {
        val first = reportService.createReport(TestData.member.id!!, memberReportRequest(TestData.member2))
        flushAndClear()

        val second = reportService.createReport(TestData.member.id!!, memberReportRequest(TestData.member2))
        flushAndClear()

        assertThat(second.isNew).isFalse()
        assertThat(second.id).isEqualTo(first.id)
        assertThat(contentReportRepository.findAll()).hasSize(1)
    }

    @Test
    fun `report is created again once the previous one is no longer open`() {
        val first = reportService.createReport(TestData.member.id!!, memberReportRequest(TestData.member2))
        flushAndClear()
        contentReportRepository.findById(first.id).orElseThrow().status = ReportStatus.RESOLVED
        flushAndClear()

        val second = reportService.createReport(TestData.member.id!!, memberReportRequest(TestData.member2))
        flushAndClear()

        assertThat(second.isNew).isTrue()
        assertThat(second.id).isNotEqualTo(first.id)
        assertThat(contentReportRepository.findAll()).hasSize(2)
    }

    @Test
    fun `alsoBlock blocks the content owner and removes the friendship`() {
        val reporter = TestData.member
        val reported = TestData.member2
        makeThemFriend(reporter, reported)
        flushAndClear()

        reportService.createReport(
            reporter.id!!,
            memberReportRequest(reported).copy(alsoBlock = true),
        )
        flushAndClear()

        assertThat(memberBlockRepository.existsByBlockerIdAndBlockedId(reporter.id!!, reported.id!!)).isTrue()
        assertThat(
            friendRelationRepository.findByMemberAndFriend(reload(reporter), reload(reported))
        ).isNull()
        assertThat(
            friendRelationRepository.findByMemberAndFriend(reload(reported), reload(reporter))
        ).isNull()
    }

    @Test
    fun `report without alsoBlock does not block`() {
        reportService.createReport(TestData.member.id!!, memberReportRequest(TestData.member2))
        flushAndClear()

        assertThat(memberBlockRepository.findAll()).isEmpty()
    }

    @Test
    fun `reporting an unknown member throws`() {
        assertThrows<NoSuchElementException> {
            reportService.createReport(
                TestData.member.id!!,
                CreateReportRequest(
                    targetType = ReportTargetType.MEMBER,
                    targetId = "-1",
                    reason = ReportReason.SPAM,
                    detail = null,
                )
            )
        }
    }

    @Test
    fun `reporting an unknown schedule throws`() {
        assertThrows<NoSuchElementException> {
            reportService.createReport(
                TestData.member.id!!,
                CreateReportRequest(
                    targetType = ReportTargetType.SCHEDULE,
                    targetId = "01912e3d-0000-7000-8000-000000000000",
                    reason = ReportReason.SPAM,
                    detail = null,
                )
            )
        }
    }

    @Test
    fun `reporting a malformed target id throws`() {
        assertThrows<NoSuchElementException> {
            reportService.createReport(
                TestData.member.id!!,
                CreateReportRequest(
                    targetType = ReportTargetType.TODO,
                    targetId = "not-a-uuid",
                    reason = ReportReason.SPAM,
                    detail = null,
                )
            )
        }
    }

    @Test
    fun `report survives member deletion with null foreign keys`() {
        val reporter = memberRepository.save(Member("reporter", "reporter@duty.park", "pass"))
        val reported = memberRepository.save(Member("reported", "reported@duty.park", "pass"))
        flushAndClear()
        val result = reportService.createReport(reporter.id!!, memberReportRequest(reported))
        flushAndClear()

        em.createNativeQuery("delete from member where id in (:ids)")
            .setParameter("ids", listOf(reporter.id!!, reported.id!!))
            .executeUpdate()
        flushAndClear()

        val report = contentReportRepository.findById(result.id).orElseThrow()
        assertThat(report.reporter).isNull()
        assertThat(report.reportedMember).isNull()
        assertThat(report.reporterName).isEqualTo("reporter")
        assertThat(report.reportedMemberName).isEqualTo("reported")
    }

    private fun memberReportRequest(
        target: Member,
        reason: ReportReason = ReportReason.SPAM,
        detail: String? = null,
    ) = CreateReportRequest(
        targetType = ReportTargetType.MEMBER,
        targetId = target.id!!.toString(),
        reason = reason,
        detail = detail,
    )

    private fun saveSchedule(member: Member, content: String, description: String): Schedule {
        return scheduleRepository.save(
            Schedule(
                member = reload(member),
                content = content,
                description = description,
                startDateTime = LocalDateTime.of(2026, 8, 18, 10, 0),
                endDateTime = LocalDateTime.of(2026, 8, 18, 11, 0),
            )
        )
    }

    private fun saveTodo(member: Member, title: String, content: String): Todo {
        return todoRepository.save(
            Todo(
                member = reload(member),
                title = title,
                content = content,
                position = 0,
            )
        )
    }

    private fun saveAttachment(
        contextType: AttachmentContextType,
        contextId: String,
        originalFilename: String,
        orderIndex: Int = 0,
    ) {
        attachmentRepository.save(
            Attachment(
                contextType = contextType,
                contextId = contextId,
                originalFilename = originalFilename,
                storedFilename = "stored-$originalFilename",
                contentType = "image/png",
                size = 100,
                storagePath = "/tmp/$originalFilename",
                orderIndex = orderIndex,
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
